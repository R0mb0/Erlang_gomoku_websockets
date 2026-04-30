Urbino`s University - Computing and digital innovation - Distributed Applications and Cloud Computing

<div align="center">
  <h1>♟️ Erlang Gomoku Websockets 🌐</h1>

  [![Codacy Badge](https://app.codacy.com/project/badge/Grade/8ae9cfa09c634094b1d150bf45ea572f)](https://app.codacy.com/gh/R0mb0/Erlang_gomoku_websockets/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
  [![pages-build-deployment](https://github.com/R0mb0/Erlang_gomoku_websockets/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/R0mb0/Erlang_gomoku_websockets/actions/workflows/pages/pages-build-deployment)
  [![Erlang](https://img.shields.io/badge/Erlang%2FOTP-28.0-a2003c.svg?logo=erlang&logoColor=white)](https://www.erlang.org/)
  [![Cowboy](https://img.shields.io/badge/Cowboy-WebSockets-20232a.svg)](https://ninenines.eu/)
  [![Tailwind](https://img.shields.io/badge/Frontend-TailwindCSS-38bdf8.svg?logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
  [![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/R0mb0/Erlang_gomoku_websockets)
  [![Open Source Love svg3](https://badges.frapsoft.com/os/v3/open-source.svg?v=103)](https://github.com/R0mb0/Erlang_gomoku_websockets)
  [![MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/license/mit)
  [![Donate](https://img.shields.io/badge/PayPal-Donate%20to%20Author-blue.svg)](http://paypal.me/R0mb0)

  <p>
    A real-time, distributed, multiplayer <strong>Gomoku (Five in a Row)</strong> engine built with <strong>Erlang/OTP</strong>. 
    It features a robust GenServer backend, a <strong>Linda-style Tuple Space</strong> architecture for state persistence, and full bidirectional communication via <strong>Cowboy WebSockets</strong>.
  </p>
</div>

<div align="center">
  <a href="http://paypal.me/R0mb0">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://github.com/R0mb0/Support_the_dev_badge/blob/main/Badge/SVG/Support_the_dev_badge_Dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="https://github.com/R0mb0/Support_the_dev_badge/blob/main/Badge/SVG/Support_the_dev_badge_Light.svg">
      <img alt="Saved you time? Support the dev" src="https://github.com/R0mb0/Support_the_dev_badge/blob/main/Badge/SVG/Support_the_dev_badge_Default.svg">
    </picture>
  </a>
</div>

<hr>

<h2>✨ Key Features</h2>
<ul>
  <li><strong>Real-Time Multiplayer:</strong> Instantaneous move broadcasting across multiple browser clients using Erlang Process Groups (<code>pg</code>).</li>
  <li><strong>Tuple Space Architecture:</strong> Adheres to the Linda coordination model, utilizing an independent Tuple Space for asynchronous decoupling of game state.</li>
  <li><strong>O(1) Deadlock Prevention:</strong> Smart internal GenServer state maps to perform instant move validations, preventing Tuple Space blocking operations (<code>in/rd</code>) from deadlocking the server.</li>
  <li><strong>Radial Win Detection:</strong> An optimized recursive algorithm that checks for 5-in-a-row specifically around the last placed stone, minimizing computational overhead.</li>
  <li><strong>Smart Frontend & Anti-Cheat:</strong> An event-driven Javascript client that auto-assigns player roles dynamically, blocks out-of-turn actions, and prevents role hijacking.</li>
</ul>

<h2>⚙️ Architectural Deep Dive</h2>
<p>This project was designed as a university-level implementation of concurrent systems. Below are the crucial architectural decisions and code implementations that power the Gomoku Arena.</p>

<h3>1. State Management: The Tuple Space vs. Deadlock Dilemma</h3>
<p>
  A pure Linda Tuple Space relies on blocking operations (like <code>in</code> or <code>rd</code>) to read data. If the server tries to read an empty cell to validate a move, and the cell isn't there, the entire <code>gen_server</code> would hang indefinitely. To solve this, we implemented a <strong>hybrid approach</strong> in <code>gomoku_server.erl</code>:
</p>
<pre><code>%% In gomoku_server.erl (handle_call/3)

%% O(1) Check using a local Map to prevent GenServer deadlocks
is_map_key({X, Y}, Board) ->
    {reply, {error, cell_occupied}, State};
true ->
    %% Architectural Compliance: Write to the Tuple Space
    tuple_space:out({cell, X, Y, Player}),
    
    %% Optimization: Update the local map for fast subsequent reads
    NewBoard = maps:put({X, Y}, Player, Board),
    ...
</code></pre>
<p>This ensures O(1) validation speed and absolute crash prevention while maintaining the Tuple Space as the ultimate source of truth.</p>

<h3>2. The Broadcasting Engine (Process Groups)</h3>
<p>
  To achieve true multiplayer functionality without polling, the server must push updates to all connected clients. When a browser connects via WebSocket, we register its Process ID (PID) to a global room using Erlang's native <code>pg</code> module in <code>gomoku_ws_handler.erl</code>.
</p>
<pre><code>%% 1. Client joins the arena upon connection
websocket_init(State) ->
    pg:join(gomoku_arena, self()),
    {ok, State}.

%% 2. Broadcasting a valid move to the entire room
Pids = pg:get_members(gomoku_arena),
lists:foreach(fun(Pid) -> Pid ! {broadcast, JsonResponse} end, Pids),
</code></pre>

<h3>3. Radial Win-Detection Algorithm</h3>
<p>
  Instead of scanning the entire 20x20 matrix (400 cells) after every move, the system only checks the 4 intersecting lines (Horizontal, Vertical, Main Diagonal, Anti-Diagonal) radiating from the exact <code>(X, Y)</code> coordinates of the latest move.
</p>
<pre><code>%% The recursive directional explorer
count_directional(X, Y, Dx, Dy, Player, Board) ->
    NextX = X + Dx,
    NextY = Y + Dy,
    case maps:get({NextX, NextY}, Board, empty) of
        Player -> 1 + count_directional(NextX, NextY, Dx, Dy, Player, Board);
        _ -> 0 %% Stops immediately at empty cells, borders, or enemy stones
    end.
</code></pre>

<h2>🛠️ Tech Stack</h2>
<ul>
  <li><strong>Backend:</strong> Erlang/OTP 28, Rebar3</li>
  <li><strong>Networking:</strong> Cowboy (HTTP/WebSocket server), Ranch</li>
  <li><strong>Data Serialization:</strong> JSX (Erlang to JSON parser)</li>
  <li><strong>Frontend:</strong> HTML5, Vanilla JavaScript, Tailwind CSS</li>
</ul>

<h2>⚡ Installation & Setup</h2>

<blockquote>
  <p><strong>⚠️ Note for Online Demo:</strong> The HTML file provided in this repository is a frontend client. To test the multiplayer features locally, you <strong>must</strong> compile and run the Erlang backend as instructed below. Opening the HTML file alone without the local server will result in a "Disconnected" state.</p>
</blockquote>

<ol>
  <li><strong>Ensure Erlang and Rebar3 are installed on your system.</strong></li>
  <li><strong>Clone the repository and navigate to the backend directory:</strong></li>
</ol>

<pre><code>git clone https://github.com/R0mb0/Erlang_gomoku_websockets.git
cd Erlang_gomoku_websockets/Gomoku/gomoku_backend
</code></pre>

<ol start="3">
  <li><strong>Compile and start the Erlang node:</strong></li>
</ol>
<p>This command fetches the Cowboy and JSX dependencies, compiles the application, and starts the supervisor tree along with the WebSocket listener on port 8080.</p>
<pre><code>rebar3 shell
</code></pre>

<ol start="4">
  <li><strong>Launch the Game:</strong></li>
</ol>
<p>Once you see the <code>===&gt; Booted gomoku_backend</code> message in your terminal, open the <code>gomoku_game.html</code> file in your web browser. </p>
<p><em>Pro-Tip: Open the file in two separate browser windows side-by-side to experience the real-time multiplayer broadcasting!</em></p>

<hr>

<a href="https://github.com/R0mb0/Not_made_by_AI">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/R0mb0/Not_made_by_AI/blob/main/Badge/SVG/NotMadeByAIDark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/R0mb0/Not_made_by_AI/blob/main/Badge/SVG/NotMadeByAILight.svg">
    <img alt="Not made by AI" src="https://github.com/R0mb0/Not_made_by_AI/blob/main/Badge/SVG/NotMadeByAIDefault.svg">
  </picture>
</a>
