-module(gomoku_server).
-behaviour(gen_server).

%% --- My Public API ---
%% Functions to interact with the game.
-export([start_link/0, init_board/0, make_move/3, print_board/0]).

%% --- Standard gen_server callbacks ---
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% The state of the game. For now, it just keeps track of whose turn it is.
-record(state, {current_turn = player_1, board = #{}}).

%% ====================================================================
%% API Functions
%% ====================================================================

%% Boot up the Game Master
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Initializes the 20x20 board with 'empty' tuples in our Tuple Space.
init_board() ->
    gen_server:cast(?MODULE, init_board).

%% Allows a player to make a move at a specific X, Y coordinate.
%% Example: gomoku_server:make_move(player_1, 5, 5).
make_move(Player, X, Y) ->
    gen_server:call(?MODULE, {make_move, Player, X, Y}).

%% Utility to print all moves currently on the board.
print_board() ->
    %% I use the wildcard '_' to get ALL cells that are NOT empty.
    Moves = tuple_space:rd({cell, '_', '_', '_'}),
    %% 'rd' currently returns a single tuple in our simple implementation.
    %% To get all tuples, we would need an 'in_all' or 'rd_all' function, 
    %% but for now, we'll just print whatever it finds or say it's empty.
    io:format("Current board state: ~p~n", [Moves]).

%% ====================================================================
%% gen_server Callbacks
%% ====================================================================

init([]) ->
    {ok, #state{current_turn = player_1, board = #{}}}.

%% Handling synchronous moves
handle_call({make_move, Player, X, Y}, _From, State) ->
    Board = State#state.board,
    if 
        Player =/= State#state.current_turn ->
            {reply, {error, not_your_turn}, State};
        X < 1 orelse X > 20 orelse Y < 1 orelse Y > 20 ->
            {reply, {error, out_of_bounds}, State};
        %% Preveniamo sovrascritture guardando la nostra mappa veloce
        is_map_key({X, Y}, Board) ->
            {reply, {error, cell_occupied}, State};
        true ->
            %% 1. Scriviamo nel Tuple Space come richiesto dall'architettura
            tuple_space:out({cell, X, Y, Player}),
            
            %% 2. Aggiorniamo la mappa locale
            NewBoard = maps:put({X, Y}, Player, Board),
            
            %% 3. Controlliamo se questa mossa scatena una vittoria
            case check_win(X, Y, Player, NewBoard) of
                true ->
                    {reply, {ok, {game_over, Player}}, State#state{board = NewBoard}};
                false ->
                    NextTurn = switch_turn(Player),
                    {reply, {ok, move_accepted}, State#state{current_turn = NextTurn, board = NewBoard}}
            end
    end;

handle_call(_Request, _From, State) ->
    {reply, error, State}.

%% Handling asynchronous initialization
handle_cast(init_board, State) ->
    %% Loop to create 20x20 = 400 empty cells
    [tuple_space:out({cell, X, Y, empty}) || X <- lists:seq(1, 20), Y <- lists:seq(1, 20)],
    io:format("Board initialized with 400 empty cells in Tuple Space.~n"),
    %% Azzeriamo anche la nostra mappa locale per i controlli veloci!
    {noreply, State#state{current_turn = player_1, board = #{}}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ====================================================================
%% Helper Functions
%% ====================================================================

switch_turn(player_1) -> player_2;
switch_turn(player_2) -> player_1.

%% --- Algoritmo di Vittoria a Raggiera ---
check_win(X, Y, Player, Board) ->
    %% Controlliamo asse Orizzontale, Verticale, e le due Diagonali
    Directions = [{1, 0}, {0, 1}, {1, 1}, {1, -1}],
    lists:any(fun({Dx, Dy}) ->
        %% Contiamo le pedine in un verso e in quello diametralmente opposto
        Count = 1 + count_directional(X, Y, Dx, Dy, Player, Board) +
                    count_directional(X, Y, -Dx, -Dy, Player, Board),
        Count >= 5
    end, Directions).

count_directional(X, Y, Dx, Dy, Player, Board) ->
    NextX = X + Dx,
    NextY = Y + Dy,
    case maps:get({NextX, NextY}, Board, empty) of
        Player -> 1 + count_directional(NextX, NextY, Dx, Dy, Player, Board);
        _ -> 0 %% Ci fermiamo appena troviamo una cella vuota, il bordo o l'avversario
    end.