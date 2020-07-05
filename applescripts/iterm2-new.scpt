on run {input, parameters}
    if application "iTerm" is running then
        tell application "iTerm"
            create window with default profile
            activate
        end tell
    else
        tell application "iTerm"
            activate
        end tell
    end if

    return input
end run
