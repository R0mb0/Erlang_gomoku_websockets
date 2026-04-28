-module(gomoku_ws_handler).

%% Cowboy WebSocket callbacks
-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2]).

init(Req, State) ->
    {cowboy_websocket, Req, State}.

websocket_init(State) ->
    io:format("~n[WebSocket] Player connected to the arena!~n"),
    %% Aggiungiamo questo Processo (self()) al gruppo globale 'gomoku_arena'
    pg:join(gomoku_arena, self()),
    {ok, State}.

%% Handle incoming TEXT/JSON messages from the browser
websocket_handle({text, Msg}, State) ->
    try jsx:decode(Msg, [return_maps]) of
        CommandMap ->
            Action = maps:get(<<"action">>, CommandMap, <<"unknown">>),
            ResponseMap = process_command(Action, CommandMap),
            JsonResponse = jsx:encode(ResponseMap),
            
            %% NOVITÀ: Invece di rispondere solo a chi ha scritto,
            %% prendiamo tutti i PID nel gruppo e mandiamo loro un messaggio Erlang interno!
            Pids = pg:get_members(gomoku_arena),
            lists:foreach(fun(Pid) -> Pid ! {broadcast, JsonResponse} end, Pids),
            
            %% Diciamo a Cowboy che per ora è tutto ok (non replichiamo direttamente al volo)
            {ok, State}
    catch
        _:_ ->
            %% In caso di errore JSON, rispondiamo privatamente a chi ha sbagliato
            ErrorJson = jsx:encode(#{<<"status">> => <<"error">>, <<"reason">> => <<"invalid_json">>}),
            {reply, {text, ErrorJson}, State}
    end;

websocket_handle(_Data, State) ->
    {ok, State}.

websocket_info({broadcast, JsonMessage}, State) ->
    {reply, {text, JsonMessage}, State};

websocket_info(_Info, State) ->
    {ok, State}.


%% ====================================================================
%% Internal Command Routing
%% ====================================================================

%% When the frontend asks to initialize the board
process_command(<<"init_board">>, _Map) ->
    gomoku_server:init_board(),
    #{<<"status">> => <<"board_initialized">>};

%% When the frontend sends a move
process_command(<<"make_move">>, Map) ->
    %% Extract X, Y, and Player from the JSON map
    PlayerBin = maps:get(<<"player">>, Map, <<"player_1">>),
    X = maps:get(<<"x">>, Map, 0),
    Y = maps:get(<<"y">>, Map, 0),
    
    %% Convert the binary string <<"player_1">> into an Erlang atom 'player_1'
    Player = erlang:binary_to_atom(PlayerBin, utf8),
    
    %% Ask the Game Master to make the move
    case gomoku_server:make_move(Player, X, Y) of
        {ok, move_accepted} ->
            #{<<"status">> => <<"move_accepted">>, 
              <<"player">> => PlayerBin, 
              <<"x">> => X, 
              <<"y">> => Y};
              
        {error, Reason} ->
            %% If it's not our turn or out of bounds, convert the atom error to binary for JSON
            #{<<"status">> => <<"error">>, 
              <<"reason">> => erlang:atom_to_binary(Reason, utf8)}
    end;

%% Fallback for unknown actions
process_command(_, _) ->
    #{<<"status">> => <<"error">>, <<"reason">> => <<"unknown_action">>}.