# 69ms logger bot

A Discord bot that env-logs / dumps Lua scripts using the `69ms` Lune tools.

## Commands (only in the configured channel)

- `.l <file | raw link | pasted code>` — env-logs with `69ms/httplog2.lua`,
  then replies `done in Ns` with the trace.
- `.dump <luraph file | raw link>` — dumps with `69ms/luraphdump.lua`. Rejects
  non-luraph input with "you can only provide luraph files", otherwise replies
  with the dump and pings you.

Links are extracted from anywhere in the message, and trailing junk is ignored,
so `.l https://host/file.lua"))()` works. Jobs run one at a time; any job that
takes longer than 60s is killed and the queue moves on.

## Setup

1. **Enable the Message Content Intent** (required — the bot won't start without it):
   Discord Developer Portal → your app → **Bot** → *Privileged Gateway Intents* →
   toggle **Message Content Intent** ON, Save.
2. Put your token + channel id in `bot/config.json` (copy from
   `config.example.json`). `config.json` is gitignored.
3. Install and run:
   ```
   cd bot
   npm install
   npm start
   ```
4. Needs `lune` on PATH (used to run `69ms/httplog2.lua` / `69ms/luraphdump.lua`).

## Security

The bot token grants full control of the bot account. It was shared in plain
text, so **regenerate it** (Developer Portal → Bot → Reset Token) and put the new
one in `config.json`. Never commit `config.json`.
