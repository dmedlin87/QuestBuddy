return {
    std = "lua51",
    max_line_length = 200,
    ignore = {
        "212",
    },
    files = {
        ["QuestBuddy.lua"] = {
            globals = {
                "QuestBuddyDB",
                "SLASH_QUESTBUDDY1",
            },
        },
        ["tests/*.lua"] = {
            globals = {
                "_ENV",
                "QuestBuddyDB",
            },
        },
    },
}
