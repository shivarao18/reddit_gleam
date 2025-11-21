# Problem Definition

- Implement a REST API interface for the engine you designed in Project 4.1. Use a structure similar to Reddit's official API (does not need to be identical).
- Implement a simple client (command line allowed) that uses the REST API to perform each piece of functionality you support.
- Run your engine with multiple clients to demonstrate that functionality works (make a video for the demo).

## Bonus

Implement a public key-based digital signature scheme for the posts. Specifically:

- A user, upon registration, provides a public key (RSA-2048 or a 256-bit Elliptic Curve).
- Add a mechanism for any user to retrieve another user's public key from the server.
- Every post has an accompanying signature computed at the time of posting.
- Each time a post is downloaded, the digital signature is checked for correctness.
