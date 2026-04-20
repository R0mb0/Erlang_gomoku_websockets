-module(gomoku_server).
-behaviour(gen_server).

-export([start_link/0, init_board/0, make_move/3, print_board/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-record(game_state, {turn = player_1}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init_board() ->
    gen_server:call(?MODULE, init_board).

make_move(Player, X, Y) ->
    gen_server:call(?MODULE, {make_move, Player, X, Y}).

print_board() ->
    gen_server:cast(?MODULE, print_board).

init([]) ->
    {ok, #game_state{}}.

handle_call(init_board, _From, State) ->
    tuple_space:clear(),
    Cells = [{cell, X, Y, empty} || X <- lists:seq(1, 20), Y <- lists:seq(1, 20)],
    lists:foreach(fun(Tuple) -> tuple_space:write(Tuple) end, Cells),
    {reply, ok, State#game_state{turn = player_1}};

handle_call({make_move, Player, X, Y}, _From, State) ->
    CurrentTurn = State#game_state.turn,
    if
        Player =/= CurrentTurn ->
            {reply, {error, not_your_turn}, State};
        true ->
            if X < 1 orelse X > 20 orelse Y < 1 orelse Y > 20 ->
                {reply, {error, out_of_bounds}, State};
            true ->
                case tuple_space:read({cell, X, Y, empty}) of
                    {ok, {cell, X, Y, empty}} ->
                        %% Mossa valida: rimuovi empty, scrivi il giocatore
                        tuple_space:take({cell, X, Y, empty}),
                        tuple_space:write({cell, X, Y, Player}),
                        
                        %% CONTROLLO VITTORIA
                        NextTurn = if Player == player_1 -> player_2; true -> player_1 end,
                        case check_victory(Player, X, Y) of
                            true -> 
                                {reply, {ok, win}, State#game_state{turn = player_1}};
                            false -> 
                                {reply, {ok, move_accepted}, State#game_state{turn = NextTurn}}
                        end;
                    _ ->
                        {reply, {error, cell_occupied}, State}
                end
            end
    end.

handle_cast(print_board, State) ->
    {ok, Tuples} = tuple_space:read_all(),
    io:format("Current board state: ~p~n", [Tuples]),
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

%% ====================================================================
%% Algoritmo di Vittoria (Novità!)
%% ====================================================================
check_victory(Player, X, Y) ->
    Directions = [{1, 0}, {0, 1}, {1, 1}, {1, -1}], % Orizzontale, Verticale, Diagonale /, Diagonale \
    lists:any(fun({Dx, Dy}) ->
        %% Conta le pedine in una direzione e in quella opposta
        Count = 1 + count_dir(Player, X, Y, Dx, Dy) + count_dir(Player, X, Y, -Dx, -Dy),
        Count >= 5
    end, Directions).

count_dir(Player, X, Y, Dx, Dy) ->
    Nx = X + Dx,
    Ny = Y + Dy,
    %% Controlla nel Tuple Space se la cella adiacente è del giocatore
    case tuple_space:read({cell, Nx, Ny, Player}) of
        {ok, _} -> 1 + count_dir(Player, Nx, Ny, Dx, Dy); % Se c'è, continua a contare
        _ -> 0 % Altrimenti fermati
    end.