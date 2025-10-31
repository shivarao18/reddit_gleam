%% Erlang FFI helper functions for distributed Reddit
-module(reddit_distributed_ffi).
-export([pid_to_subject/1, dynamic_to_pid/1, distributed_call/3, dynamic_to_any/1]).

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
%% Subject is {gleam_erlang_subject, Pid}
%% Message is the protocol message
%% Timeout is in milliseconds
distributed_call({gleam_erlang_subject, Pid}, Message, Timeout) ->
    try
        gen_server:call(Pid, Message, Timeout)
    catch
        exit:Reason -> {error, Reason};
        error:Reason -> {error, Reason}
    end;
distributed_call(Pid, Message, Timeout) when is_pid(Pid) ->
    try
        gen_server:call(Pid, Message, Timeout)
    catch
        exit:Reason -> {error, Reason};
        error:Reason -> {error, Reason}
    end.

%% Identity function to convert Dynamic to any type
%% The Erlang type system already matches, so this is safe
dynamic_to_any(Value) ->
    Value.

