%% Erlang FFI helper functions for distributed Reddit
-module(reddit_distributed_ffi).
-export([pid_to_subject/1]).

%% Convert a Pid to a Subject for message passing
pid_to_subject(Pid) when is_pid(Pid) ->
    %% In Gleam's OTP, a Subject is essentially a wrapped Pid
    %% We create a subject-like structure
    {gleam_erlang_subject, Pid}.

