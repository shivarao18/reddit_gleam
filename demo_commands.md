gleam run -m reddit_server


curl http://localhost:3000/health

curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"alice\"}"

curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"bob\"}"

curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"charlie\"}"

----

curl -X POST http://localhost:3000/api/subreddits/create -H "Content-Type: application/json" -d "{\"name\":\"gleam\",\"description\":\"A community for Gleam programming language\",\"creator_id\":\"user_1\"}"

curl -X POST http://localhost:3000/api/subreddits/create -H "Content-Type: application/json" -d "{\"name\":\"programming\",\"description\":\"General programming discussion\",\"creator_id\":\"user_2\"}"

curl http://localhost:3000/api/subreddits

---

curl -X POST http://localhost:3000/api/subreddits/sub_1/join -H "Content-Type: application/json" -d "{\"user_id\":\"user_1\"}"

curl -X POST http://localhost:3000/api/subreddits/sub_2/join -H "Content-Type: application/json" -d "{\"user_id\":\"user_2\"}"

curl -X POST http://localhost:3000/api/subreddits/sub_2/join -H "Content-Type: application/json" -d "{\"user_id\":\"user_1\"}"

----

curl -X POST http://localhost:3000/api/posts/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_1\",\"subreddit_id\":\"sub_1\",\"title\":\"Why Gleam is awesome\",\"content\":\"Gleam brings type safety to the BEAM!\"}"

curl -X POST http://localhost:3000/api/posts/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_2\",\"subreddit_id\":\"sub_2\",\"title\":\"REST APIs with Gleam\",\"content\":\"Building REST APIs is easy with Mist and Wisp\"}"


---

curl -X POST http://localhost:3000/api/comments/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_3\",\"post_id\":\"post_1\",\"content\":\"Great post!\"}"

curl -X POST http://localhost:3000/api/posts/post_1/vote -H "Content-Type: application/json" -d "{\"user_id\":\"user_2\",\"vote_type\":\"upvote\"}"

curl -X POST http://localhost:3000/api/comments/comment_1/vote -H "Content-Type: application/json" -d "{\"user_id\":\"user_1\",\"vote_type\":\"upvote\"}"

---

curl http://localhost:3000/api/feed/user_1

---

curl -X POST http://localhost:3000/api/dm/send -H "Content-Type: application/json" -d "{\"from_user_id\":\"user_1\",\"to_user_id\":\"user_2\",\"content\":\"Hey Bob, check out my post!\"}"

curl -X POST http://localhost:3000/api/dm/send -H "Content-Type: application/json" -d "{\"from_user_id\":\"user_2\",\"to_user_id\":\"user_1\",\"content\":\"Thanks Alice, will do!\"}"

curl http://localhost:3000/api/dm/user/user_1

curl http://localhost:3000/api/dm/conversation/user_1/user_2

----

gleam run -m reddit_client

----

gleam run -m reddit_multi_client


----

### Bonus Demo:

gleam run -m reddit_server

---

gleam run -m reddit_crypto_demo

---

# PREREQUISITE: Generate valid crypto keys first
gleam run -m reddit_key_generator
# Copy the generated public keys from the output

---

curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"alice\",\"public_key\":\"g2gCbAAAAAJtAAAAAwEAAW0AAAEAg/WfltEYBtNi9gO30EYxknbg5VveklmzzB88xG6QPmtSDDRuEtNm+UMpD9juKpq4Dt7+VvylNq4Cw6w5VbBRI/FgwNOmDzPLBhNPcsOSqc+lwLmcATooHCMygxQ8s+qf2wpQhExfLHyfRRDQZiynqkV4q5rKxi+/HIpoAzWJdE5l064SQCuztThI+fxeWBZ68LlmzO1c0znYwm/wK9+nFYiRJAyeRvjczwUFsiU497GTQzURNjhuvk1YOzqC502GGuHgLEgPzjvC5uooHh2mu/xl3dhtuy/XVL/lsxsYpfO3wL29tYYaWPu000m6NcjK3kIarQBiuFbt1CZvj0ZdoWpsAAAACG0AAAADAQABbQAAAQCD9Z+W0RgG02L2A7fQRjGSduDlW96SWbPMHzzEbpA+a1IMNG4S02b5QykP2O4qmrgO3v5W/KU2rgLDrDlVsFEj8WDA06YPM8sGE09yw5Kpz6XAuZwBOigcIzKDFDyz6p/bClCETF8sfJ9FENBmLKeqRXirmsrGL78cimgDNYl0TmXTrhJAK7O1OEj5/F5YFnrwuWbM7VzTOdjCb/Ar36cViJEkDJ5G+NzPBQWyJTj3sZNDNRE2OG6+TVg7OoLnTYYa4eAsSA/OO8Lm6igeHaa7/GXd2G27L9dUv+WzGxil87fAvb21hhpY+7TTSbo1yMreQhqtAGK4Vu3UJm+PRl2hbQAAAQAbMYdhO5axdWdr3klHdOerUK845M1BqJWqR3es3UIBcvlWBYn3fDQ4wtPX7bLq+bZbbi3IvEjJs2Njcn7gPzUBbLEtG5CZimlYx6r0MgRr1RxJ0pYpFJSGc+Rpaca2pu+pYn9EPD7Sup3RzEy9+Y7VwnpDFuOZouZF2enkW2iHnIKTn8kpHsP/qpaph6/0WRz66/Y0DFJAT95wGYBlI3H28yfF0yndM4r5ccDh8FMINw1qwyRxbXXktfnjpZZDP/KQ7AaVPtcgWaKJkiafrZl0i2aJ990tMqtyI/PCi8joEsRi2LnngqzUp/iwT3CSv75utGRFNQr6uL718+WfXMEfbQAAAIC3my8yUt93Fir48X/LYphDqouFlpHYUcEQDQxVba0a97zgbHQ23VcQPdErc8tDktHZffXL6XHiNWQBpomHC/5GyUB+etTGC1avfIKf1g0xPQY7CQ2ACaN6D84gYjqILIJ6jIr0B50z6y5/MbEo+uPEwCqOTjZaGPxPF9chIYHJ620AAACAt/1UVXEV487McQqcye2xEQzcE3Zltbhy/3iI0E7M75EqGiWHByQ6q3ZM/Y20HqY9TiCQGfeGtgslW6sAimmj9jhv6Ikdc6YWXv7qSCssGkfVP/zdrCeV4vlEfkppoW66tdoS1YC/VZN/ctUV34Vm03ESZwbNcSywgLdYoYOgJ6NtAAAAgKm/6Ne+9OmV7i7wn/U694l/8LSWa8qycytS1PdaijOnndFjk+Jxqx/R90QUL3YPFMLfCNP4xZidQhOgk//uX620PVNyXqunKgLeu6no7ZN7VvpXuUqKHsEoQauBBZqGhC+nJoTNUVMB+aARIjjAFLr/65hbyTZtaT/6y6PO5b73bQAAAICd08e2C221nz2scmgQp77OW3OlllilS3YKQ8FIv2/4yVOOXka4D5HsZ2yfzCCIch4AmNpEDBsYqfL/8W5jTT+DBOKqXIRRIlXqY01hXvdUC+6YFzeoZ8ShkSX6F6cI/c1YFZs2XlzC8eXQAY3j0bFlC4e3rRQqUyWNJLn4wsptdW0AAACAMbpT1iJDmzRDBnIdRaPwTB5RNtYQVQMAzB4sICfyeIs6ph8df0FEAR8l0qFobWiBAQNcWlpC4pSwCrhfBFnd7Qsph7lpLh/F8+YcAq88H5aOFFF+VvXc6lPJFJU3BSckFjHiibxu8lWiU/Jb/7BHkPeHZdeIvKBsU9FHbRzAlahq",\"key_algorithm\":\"RSA2048\"}"

curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"bob\",\"public_key\":\"g2gCbQAAAEEEOGA45PRaIctltO75zyGnm1aHCmW35VtP7BuF/xIwM1BqhNcqSGk02UeeQ/pD49nq6c/cQx+5iKzPFnuphCQfwG0AAAAgaQs114xwoy0kFnWr8ouWYTqfxfhUCa6qZZWiOWpGhow=",\"key_algorithm\":\"ECDSA_P256\"}"s


curl -X POST http://localhost:3000/api/auth/register -H "Content-Type: application/json" -d "{\"username\":\"charlie\"}"

---

curl -X POST http://localhost:3000/api/subreddits/create -H "Content-Type: application/json" -d "{\"name\":\"crypto\",\"description\":\"Cryptography discussion\",\"creator_id\":\"user_1\"}"


---

curl -X POST http://localhost:3000/api/posts/create -H "Content-Type: application/json" -d "{\"author_id\":\"user_1\",\"subreddit_id\":\"sub_1\",\"title\":\"RSA Digital Signatures\",\"content\":\"RSA provides strong authentication and integrity\",\"signature\":\"<alice_signature_base64>\",\"signature_algorithm\":\"RSA2048\"}"

---

curl http://localhost:3000/api/posts/post_1


---
rerun server

gleam run -m reddit_client

gleam run -m reddit_multi_client

---

gleam test

