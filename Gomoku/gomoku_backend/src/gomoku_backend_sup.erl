-module(gomoku_backend_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

%% Starts the supervisor process
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% Initializes the supervisor and defines its children
init([]) ->
    %% strategy: one_for_one -> If a child dies, restart ONLY that child.
    %% intensity: 5, period: 10 -> Allow max 5 crashes in 10 seconds before giving up.
    SupFlags = #{strategy => one_for_one, intensity => 5, period => 10},

    %% We define our two actors. The supervisor will start them automatically!
    ChildSpecs = [
        #{id => tuple_space,
          start => {tuple_space, start_link, []},
          restart => permanent, % Always restart it if it crashes
          type => worker},

        #{id => gomoku_server,
          start => {gomoku_server, start_link, []},
          restart => permanent,
          type => worker}
    ],

    {ok, {SupFlags, ChildSpecs}}.