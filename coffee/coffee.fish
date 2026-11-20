# coffee: keep the Mac awake from the terminal, using caffeinate.
#
#   coffee              # indefinitely
#   coffee -d 1.5       # for 1.5 hours
#   coffee -t 5:00pm    # until 5:00 PM (also 5pm, 17:00)
#
# While running, one status line updates in place: q quits, a adds time
# (2 for 2h, 1:30 for 1h 30m), c changes the end time.

function __coffee_parse_time --argument-names text
    set -l epoch
    for format in "%I:%M%p" "%I:%M %p" "%I%p" "%H:%M"
        if test -z "$epoch"
            set epoch (date -j -f "$format" "$text" "+%s" 2>/dev/null)
        end
    end
    # A time already past today means tomorrow.
    if test -n "$epoch"; and test $epoch -le (date "+%s")
        set epoch (math "$epoch + 86400")
    end

    echo $epoch
end

function __coffee_parse_duration --argument-names text
    if string match -q '*:*' "$text"
        set -l parts (string split ':' "$text")
        math "$parts[1] * 3600 + $parts[2] * 60" 2>/dev/null
    else
        math "$text * 3600" 2>/dev/null
    end
end

function __coffee_format_duration --argument-names seconds
    set -l minutes (math -s 0 "ceil($seconds / 60)")
    set -l hours (math -s 0 "floor($minutes / 60)")
    if test $hours -gt 0
        printf "%dh %dm" $hours (math "$minutes % 60")
    else
        printf "%dm" $minutes
    end
end

# Redraw the status line in place, with an optional note in front of it.
function __coffee_status --argument-names end_epoch note
    set -l status_text "Awake indefinitely"
    if test $end_epoch -ne 0
        set -l end_time (string trim (date -j -f "%s" "$end_epoch" "+%l:%M %p"))
        set -l remaining (math "$end_epoch - "(date "+%s"))
        set status_text "Awake until $end_time ("(__coffee_format_duration $remaining)")"
    end
    if test -n "$note"
        set status_text "$note  $status_text"
    end
    printf "\r\033[K%s | [q]uit [a]dd [c]hange" $status_text
end

# Erase the prompt line left behind by `read` and return to the status line.
function __coffee_clear_prompt
    printf "\033[1A\r\033[K"
end

function coffee --description "Keep the Mac awake"
    argparse 'd/duration=' 't/time=' 'h/help' -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: coffee [-d HOURS | -t TIME]"
        echo "  -d, --duration HOURS   stay awake for HOURS (3, 1.5)"
        echo "  -t, --time TIME        stay awake until TIME (5:00pm, 5pm, 17:00)"
        echo "With no options, stays awake indefinitely. While running: q quit, a add time, c change end."
        return 0
    end

    set -l end_epoch 0
    if set -q _flag_duration
        set -l seconds (__coffee_parse_duration "$_flag_duration")
        if test -z "$seconds"
            echo "Could not read '$_flag_duration' as a duration."
            return 1
        end
        set end_epoch (math -s 0 (date "+%s")" + $seconds")
    else if set -q _flag_time
        set end_epoch (__coffee_parse_time "$_flag_time")
        if test -z "$end_epoch"
            echo "Could not read '$_flag_time' as a time. Try 5:00pm, 5pm, or 17:00."
            return 1
        end
    end

    # -w ties caffeinate to this shell, so it cannot outlive a closed terminal.
    caffeinate -di -w $fish_pid &
    set -l caffeinate_pid $last_pid
    set -l note ""
    set -l done_text "Done. The Mac can sleep now."

    while true
        if test $end_epoch -ne 0; and test (date "+%s") -ge $end_epoch
            break
        end
        if not kill -0 $caffeinate_pid 2>/dev/null
            set done_text "caffeinate stopped unexpectedly."
            break
        end

        __coffee_status $end_epoch "$note"

        # Single keypress with a timeout; fish's own read -t is unreliable here.
        stty raw -echo 2>/dev/null
        set -l key (bash -c 'read -t 2 -n 1 key 2>/dev/null && echo "$key"')
        stty sane 2>/dev/null

        if test -n "$key"
            set note ""
            switch $key
                case q Q \cc
                    break

                case a A '+' '='
                    printf "\r\033[K"
                    read -l -P "Add time (2 or 1:30): " text
                    __coffee_clear_prompt
                    set -l seconds (__coffee_parse_duration "$text")
                    if test -n "$seconds"; and test "$seconds" -gt 0
                        if test $end_epoch -eq 0
                            set end_epoch (date "+%s")
                        end
                        set end_epoch (math -s 0 "$end_epoch + $seconds")
                    else if test -n "$text"
                        set note "Could not read '$text'."
                    end

                case c C
                    printf "\r\033[K"
                    read -l -P "New end time (5:00pm): " text
                    __coffee_clear_prompt
                    set -l epoch (__coffee_parse_time "$text")
                    if test -n "$epoch"
                        set end_epoch $epoch
                    else if test -n "$text"
                        set note "Could not read '$text'."
                    end
            end
        end
    end

    kill $caffeinate_pid 2>/dev/null
    printf "\r\033[K%s\n" $done_text
end
