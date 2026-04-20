-module(gomoku_ws_handler).
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2]).

init(Req, State) -> {cowboy_websocket, Req, State}.
websocket_init(State) -> {ok, State}.

websocket_handle({text, Msg}, State) ->
    try jsx:decode(Msg, [return_maps]) of
        CommandMap ->
            Action = maps:get(<<"action">>, CommandMap, <<"unknown">>),
            ResponseMap = process_command(Action, CommandMap),
            {reply, {text, jsx:encode(ResponseMap)}, State}
    catch
        _:_ ->
            {reply, {text, jsx:encode(#{<<"status">> => <<"error">>, <<"reason">> => <<"invalid_json">>})}, State}
    end;
websocket_handle(_Data, State) -> {ok, State}.
websocket_info(_Info, State) -> {ok, State}.

process_command(<<"init_board">>, _Map) ->
    gomoku_server:init_board(),
    #{<<"status">> => <<"board_initialized">>};

process_command(<<"make_move">>, Map) ->
    PlayerBin = maps:get(<<"player">>, Map, <<"player_1">>),
    X = maps:get(<<"x">>, Map, 0),
    Y = maps:get(<<"y">>, Map, 0),
    Player = erlang:binary_to_atom(PlayerBin, utf8),
    
    case gomoku_server:make_move(Player, X, Y) of
        {ok, move_accepted} ->
            #{<<"status">> => <<"move_accepted">>, <<"player">> => PlayerBin, <<"x">> => X, <<"y">> => Y};
            
        %% NUOVA RIGA: Gestione della vittoria
        {ok, win} ->
            #{<<"status">> => <<"win">>, <<"player">> => PlayerBin, <<"x">> => X, <<"y">> => Y};
            
        {error, Reason} ->
            #{<<"status">> => <<"error">>, <<"reason">> => erlang:atom_to_binary(Reason, utf8)}
    end;

process_command(_, _) ->
    #{<<"status">> => <<"error">>, <<"reason">> => <<"unknown_action">>}.