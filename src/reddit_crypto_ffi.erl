-module(reddit_crypto_ffi).
-export([generate_rsa_keypair/1, generate_ecdsa_keypair/0, sign_rsa/2, sign_ecdsa/2, verify_rsa/3, verify_ecdsa/3]).

% Generate RSA key pair
% Returns the keys in Erlang's internal format, serialized to binary via term_to_binary
generate_rsa_keypair(Bits) ->
    try
        % Generate RSA key pair - returns {PublicKey, PrivateKey}
        % Both are in the format [E, N] for public and [E, N, D, P1, P2, E1, E2, C] for private
        KeyPair = crypto:generate_key(rsa, {Bits, 65537}),
        
        % Serialize the entire keypair to binary
        KeyPairBin = term_to_binary(KeyPair),
        
        % We'll store both in the serialized format
        {ok, {KeyPairBin, KeyPairBin}}
    catch
        Error:Reason ->
            ErrorMsg = io_lib:format("RSA generation failed: ~p:~p", [Error, Reason]),
            {error, list_to_binary(ErrorMsg)}
    end.

% Generate ECDSA key pair (P-256 / secp256r1)
generate_ecdsa_keypair() ->
    try
        % Generate ECDSA key pair
        % Returns {PublicKeyPoint, PrivateKeyBin}
        KeyPair = crypto:generate_key(ecdh, secp256r1),
        
        % Serialize
        KeyPairBin = term_to_binary(KeyPair),
        
        {ok, {KeyPairBin, KeyPairBin}}
    catch
        Error:Reason ->
            ErrorMsg = io_lib:format("ECDSA generation failed: ~p:~p", [Error, Reason]),
            {error, list_to_binary(ErrorMsg)}
    end.

% Sign message with RSA
sign_rsa(Message, KeyPairBin) ->
    try
        % Deserialize keypair
        {_PublicKey, PrivateKey} = binary_to_term(KeyPairBin),
        
        % Sign with RSA - private key should be [E, N, D, ...] format
        Signature = crypto:sign(rsa, sha256, Message, PrivateKey),
        {ok, Signature}
    catch
        Error:Reason ->
            ErrorMsg = io_lib:format("RSA signing failed: ~p:~p", [Error, Reason]),
            {error, list_to_binary(ErrorMsg)}
    end.

% Sign message with ECDSA
sign_ecdsa(Message, KeyPairBin) ->
    try
        % Deserialize keypair
        {_PublicKey, PrivateKey} = binary_to_term(KeyPairBin),
        
        % ECDSA private key is a binary
        Signature = crypto:sign(ecdsa, sha256, Message, [PrivateKey, secp256r1]),
        {ok, Signature}
    catch
        Error:Reason ->
            ErrorMsg = io_lib:format("ECDSA signing failed: ~p:~p", [Error, Reason]),
            {error, list_to_binary(ErrorMsg)}
    end.

% Verify RSA signature
verify_rsa(Message, Signature, KeyPairBin) ->
    try
        % Deserialize keypair
        {PublicKey, _PrivateKey} = binary_to_term(KeyPairBin),
        
        % Public key should be [E, N] format
        crypto:verify(rsa, sha256, Message, Signature, PublicKey)
    catch
        _:_ -> false
    end.

% Verify ECDSA signature
verify_ecdsa(Message, Signature, KeyPairBin) ->
    try
        % Deserialize keypair
        {PublicKey, _PrivateKey} = binary_to_term(KeyPairBin),
        
        % PublicKey is an EC point
        crypto:verify(ecdsa, sha256, Message, Signature, [PublicKey, secp256r1])
    catch
        _:_ -> false
    end.



