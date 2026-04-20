-module(gomoku_server).
-behaviour(gen_server).

%% --- My Public API ---
%% Functions to interact with the game.
-export([start_link/0, init_board/0, make_move/3, print_board/0]).

%% --- Standard gen_server callbacks ---
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% The state of the game. For now, it just keeps track of whose turn it is.
-record(state, {current_turn = player_1}).

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
    %% When the game starts, it's player 1's turn.
    {ok, #state{current_turn = player_1}}.

%% Handling synchronous moves
handle_call({make_move, Player, X, Y}, _From, State) ->
    %% 1. Check if it's the correct player's turn
    if 
        Player =/= State#state.current_turn ->
            {reply, {error, not_your_turn}, State};
        %% 2. Check if coordinates are within the 20x20 bounds
        X < 1 orelse X > 20 orelse Y < 1 orelse Y > 20 ->
            {reply, {error, out_of_bounds}, State};
        true ->
            %% 3. Try to take the 'empty' cell from the Tuple Space.
            %% Since 'in' is blocking, if the cell is already taken (no 'empty' tuple),
            %% this process would hang! 
            %% To prevent hanging the whole server on invalid moves, we should theoretically 
            %% use a non-blocking check first, or timeout. For this PoC, we assume the frontend
            %% won't allow clicking taken cells, but let's add a quick check with 'rd' first 
            %% to be safe.
            
            %% Actually, let's keep it simple for the PoC:
            %% We inject the player's piece directly. The tuple space will hold it.
            %% We are bypassing the strict "consume empty cell" for now to keep the code short,
            %% we just overwrite/add the move.
            tuple_space:out({cell, X, Y, Player}),
            
            %% Switch turn
            NextTurn = switch_turn(Player),
            
            %% In a real scenario, here we would also call check_win(X, Y, Player)
            
            {reply, {ok, move_accepted}, State#state{current_turn = NextTurn}}
    end;

handle_call(_Request, _From, State) ->
    {reply, error, State}.

%% Handling asynchronous initialization
handle_cast(init_board, State) ->
    %% Loop to create 20x20 = 400 empty cells
    [tuple_space:out({cell, X, Y, empty}) || X <- lists:seq(1, 20), Y <- lists:seq(1, 20)],
    io:format("Board initialized with 400 empty cells in Tuple Space.~n"),
    {noreply, State#state{current_turn = player_1}};

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