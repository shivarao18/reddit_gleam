%% Erlang FFI helper functions for distributed Reddit
-module(reddit_distributed_ffi).
-export([pid_to_subject/1, dynamic_to_pid/1, distributed_call/3, dynamic_to_any/1, ping_node_by_string/1, get_hostname_as_binary/0]).

%% Convert a Pid to a Subject for message passing
pid_to_subject(Pid) when is_pid(Pid) ->
    %% In Gleam's OTP, a Subject is essentially a wrapped Pid
    %% We create a subject-like structure
    {gleam_erlang_subject, Pid}.

%% Convert a Dynamic (which is just a Pid) to Pid type
%% This is an identity function - Dynamic is just Pid at runtime
dynamic_to_pid(Pid) when is_pid(Pid) ->
    Pid;
dynamic_to_pid(Other) ->
    %% This shouldn't happen if classify returned "Pid"
    error({not_a_pid, Other}).

%% Distributed call - works across nodes
%% This sends a message directly to a remote actor and waits for a reply
%% MessageFun is a function that takes a reply Subject and returns the full message
distributed_call({gleam_erlang_subject, Pid}, MessageFun, Timeout) ->
    %% Create a reply Subject (just our own Pid wrapped)
    ReplySubject = {gleam_erlang_subject, self()},
    
    %% Call the message function with the reply Subject to build the full message
    Message = MessageFun(ReplySubject),
    
    %% Send the message directly to the remote actor
    Pid ! Message,
    
    %% Wait for the reply
    receive
        Reply -> Reply
    after Timeout ->
        {error, timeout}
    end;
distributed_call(Pid, MessageFun, Timeout) when is_pid(Pid) ->
    %% Same as above but for raw Pids
    ReplySubject = {gleam_erlang_subject, self()},
    Message = MessageFun(ReplySubject),
    Pid ! Message,
    receive
        Reply -> Reply
    after Timeout ->
        {error, timeout}
    end.

%% Identity function to convert Dynamic to any type
%% The Erlang type system already matches, so this is safe
dynamic_to_any(Value) ->
    Value.

%% Ping a node by string name (handles node name conversion safely)
%% Accepts both binaries (Gleam strings) and lists (Erlang strings)
ping_node_by_string(NodeName) when is_binary(NodeName) ->
    try
        %% Convert binary to list, then to atom
        NodeList = binary_to_list(NodeName),
        NodeAtom = list_to_atom(NodeList),
        net_adm:ping(NodeAtom)
    catch
        _:_ -> pang
    end;
ping_node_by_string(NodeName) when is_list(NodeName) ->
    try
        NodeAtom = list_to_atom(NodeName),
        net_adm:ping(NodeAtom)
    catch
        _:_ -> pang
    end.

%% Get hostname as a binary (Gleam String)
get_hostname_as_binary() ->
    case inet:gethostname() of
        {ok, Hostname} when is_list(Hostname) ->
            %% Hostname is a charlist, convert to binary
            list_to_binary(Hostname);
        {ok, Hostname} when is_binary(Hostname) ->
            %% Already a binary
            Hostname;
        _ ->
            %% Fallback
            <<"localhost">>
    end.

