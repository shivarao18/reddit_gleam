# Reddit Clone Project

## Overview
In this project, you have to implement a **Reddit Clone** and a **client tester/simulator**.

As **Part I** of this project, you need to build an **engine** that (in Part II) will be paired up with **REST API/WebSockets** to provide full functionality.

- The official Reddit API documentation can be found here:  
  [https://www.reddit.com/dev/api/](https://www.reddit.com/dev/api/)
- An overview of Reddit and its functionality can be found here:  
  [https://www.oberlo.com/blog/what-is-reddit](https://www.oberlo.com/blog/what-is-reddit)

In **Part I**, you are **only building the engine and a simulator**, not the API or web clients.

---

## Requirements

### Reddit-like Engine Functionality
Implement a Reddit-like engine with the following features:

- **Register account**
- **Create & join sub-reddit; leave sub-reddit**
- **Post in sub-reddit**
  - Posts are simple text only — no images or markdown support.
- **Comment in sub-reddit**
  - Comments are hierarchical (i.e., you can comment on a comment).
- **Upvote / Downvote + compute Karma**
- **Get feed of posts**
- **Get list of direct messages; reply to direct messages**

---

### Tester/Simulator
Implement a **tester/simulator** to test the above functionality:

- Simulate as many users as possible
- Simulate **periods of live connection and disconnection** for users
- Simulate a **Zipf distribution** on the number of sub-reddit members  
  - For accounts with many subscribers, increase the number of posts  
  - Include some **re-posts** among the messages

---

## Other Considerations

- The **client part** (posting, commenting, subscribing) and the **engine** (distribute posts, track comments, etc.) must run in **separate processes**.
- Preferably:
  - Use **multiple independent client processes** that simulate thousands of clients.
  - Have a **single engine process**.
- You need to **measure and report performance metrics** of your simulator.

---

