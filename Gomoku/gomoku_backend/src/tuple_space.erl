-module(tuple_space).
-behaviour(gen_server).

%% --- My Public API ---
%% These are the functions I'll call from the Erlang shell or from other modules in my project.
-export([start_link/0, out/1, in/1, rd/1]).

%% --- Standard gen_server callbacks ---
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% Defining my server state here. 
%% 'store' will hold the ETS table ID (my memory for the tuples).
%% 'waiting' is a queue where I'll park clients that are blocked on an 'in' or 'rd' waiting for a tuple to arrive.
-record(state, {store, waiting = []}).

%% ====================================================================
%% API Functions
%% ====================================================================

%% Booting up the server and registering it locally as 'tuple_space' so I can easily ping it.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% OUT: Drops a tuple into the space. I don't need to wait for a reply here, 
%% so a 'cast' (fire-and-forget) is the perfect asynchronous choice.
out(Tuple) ->
    gen_server:cast(?MODULE, {out, Tuple}).

%% IN: Searches for a tuple and removes it (destructive read). 
%% Since the Linda model dictates this should block if the tuple isn't there, 
%% I'm using a synchronous 'call' with an 'infinity' timeout.
in(Pattern) ->
    gen_server:call(?MODULE, {in, Pattern}, infinity).

%% RD: Same logic as 'in', but I leave the tuple in the space (non-destructive read).
rd(Pattern) ->
    gen_server:call(?MODULE, {rd, Pattern}, infinity).

%% ====================================================================
%% gen_server Callbacks (The actual engine)
%% ====================================================================

init([]) ->
    %% When the server starts, I immediately create my ETS table called 'tuples'.
    %% I chose 'bag' because I might want to store identical duplicate tuples in my space.
    Store = ets:new(tuples, [bag, private]),
    {ok, #state{store = Store}}.

%% Handling synchronous requests (in and rd)
handle_call({in, Pattern}, From, State) ->
    %% Let's see if I already have a match in my ETS table
    case ets:match_object(State#state.store, Pattern) of
        [Tuple | _] -> 
            %% Found it! I'm removing it from the table (destructive read)
            ets:delete_object(State#state.store, Tuple),
            %% And sending it right back to the client
            {reply, Tuple, State};
        [] ->
            %% Not found... Okay, I won't reply just yet. 
            %% I'll park the client and their pattern in my 'waiting' queue. 
            %% They'll stay blocked while my server keeps spinning and accepting new requests.
            NewWaiting = State#state.waiting ++ [{in, Pattern, From}],
            {noreply, State#state{waiting = NewWaiting}}
    end;

handle_call({rd, Pattern}, From, State) ->
    %% Same logic as 'in', but if I find it, I don't delete it.
    case ets:match_object(State#state.store, Pattern) of
        [Tuple | _] -> 
            {reply, Tuple, State};
        [] ->
            %% No match, queuing this client up too.
            NewWaiting = State#state.waiting ++ [{rd, Pattern, From}],
            {noreply, State#state{waiting = NewWaiting}}
    end;

%% Fallback for unsupported calls
handle_call(_Request, _From, State) ->
    {reply, error, State}.

%% Handling the 'out' cast (asynchronous)
handle_cast({out, Tuple}, State) ->
    %% Saving the new tuple into memory
    ets:insert(State#state.store, Tuple),
    %% Now for the clever part: let's check if there's anyone parked in the waiting queue 
    %% who was looking for exactly this tuple!
    NewWaiting = process_waiting(State#state.waiting, State#state.store, []),
    %% Updating the state with the cleaned-up waiting list
    {noreply, State#state{waiting = NewWaiting}};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Standard fallback for unexpected messages
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ====================================================================
%% My internal helper functions
%% ====================================================================

%% This helper function iterates through the waiting queue to see if I can unblock anyone now that a new tuple arrived.
process_waiting([], _Store, Acc) ->
    %% Done looping. I need to reverse the accumulator to preserve the original waiting order before returning it.
    lists:reverse(Acc);
process_waiting([{Type, Pattern, From} = Request | Rest], Store, Acc) ->
    %% Checking the match again for each waiting request
    case ets:match_object(Store, Pattern) of
        [Tuple | _] when Type =:= in ->
            %% Yay, match for an 'in'! I delete the tuple and use 'reply' to manually unblock the client.
            ets:delete_object(Store, Tuple),
            gen_server:reply(From, Tuple),
            %% Moving on to the next request without adding this one back to the accumulator
            process_waiting(Rest, Store, Acc);
        [Tuple | _] when Type =:= rd ->
            %% Match for an 'rd'. I reply, but don't delete the tuple.
            gen_server:reply(From, Tuple),
            process_waiting(Rest, Store, Acc);
        [] ->
            %% Still no match for this request. Keeping it in the waiting queue accumulator.
            process_waiting(Rest, Store, [Request | Acc])
    end.