#! /bin/bash
eps=1e-6
float_scale=6
stu_input="/tmp/judge.stu_input"
stu_output="/tmp/judge.stu_output"
data_dir="testcases/"
src_dir="src/"
bin_dir="bin/"
mkdir -p "$bin_dir"
mkdir -p "$src_dir"

function test_exp {
    local exp=$1
    local val=$2
    echo "exp: \"$exp\", val: \"$val\""
    [[ $(guile -c "(display (< (magnitude (- $exp $val)) $eps))") == "#t" ]]
}

function special_judge {
    local datafile="$1"
    local stuprog="$2"
    local lvl=0
    local buff=""
    local exps=()
    shift 2
    echo 1>&2 "*** Special Judge: $datafile ***"
    while IFS="" read -rn 1 ch; do
        if [[ "$ch" == "(" ]]; then
            let lvl++
        elif [[ "$ch" == ")" ]]; then
            let lvl--
        fi
        buff+="$ch"
        if [[ "$lvl" -eq 0 && -n "$buff" ]]; then
            exps+=("$buff")
            echo 1>&2 "Found expression: $buff"
            buff=""
        fi
    done < "$datafile"
    IFS=$'\n'
        for exp in "${exps[@]}"
        do 
            echo "(display $exp)"
            echo "(display \"\n\")"
        done > "$stu_input"
        res=($("$stuprog" "$stu_input" $@ 2> /dev/null))
    local i=0
    for exp in "${exps[@]}"; do
        test_exp "$exp" "${res[i]}"
        if [[ "$?" != "0" ]]; then
            echo "Wrong!"
            return 1
        else
            echo "OK."
        fi
        let i++
    done
    return 0
}

function fullcmp_judge {
    local datafile="$1"
    local stuprog="$2"
    echo 1>&2 "*** Judge: $datafile ***"
    "$stuprog" "$datafile" > "$stu_output"
    guile -s "$datafile" | diff - "$stu_output"
}

function float_eval()
{
    local stat=0
    local result=0.0
    if [[ $# -gt 0 ]]; then
        result=$(echo "scale=$float_scale; $*" | bc -q 2>/dev/null)
        stat=$?
        if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
    fi
    echo $result
    return $stat
}

function all_judge {
    local __score="$1"
    local stuprog="$2"
    local correct0=0
    local correct1=0
    local all0=0
    local all1=0
    for c in "$data_dir/arithmetic/"*.scm; do
        (special_judge "$c" "$stuprog") && ((correct0++))
        let all0++
    done
    for c in "$data_dir/misc/"*.scm; do
        (fullcmp_judge "$c" "$stuprog") && ((correct1++))
        let all1++
    done
    echo "correct0 = $correct0, all0 = $all0"
    echo "correct1 = $correct1, all1 = $all1"
    eval $__score="$(float_eval "$correct0 / $all0 + $correct1 / $all1")"
}

function build {
    local stu_bin="$1"
    local stu_dir="$2"
    g++ -DGMP_SUPPORT -lgmp -o "$stu_bin" $(find "$stu_dir" -name "*.cpp")
}

function judge {
    for stu_dir in "$src_dir"/*; do
        echo "$stu_dir"
        if [ -d "$stu_dir" ]; then
            echo 1>&2 "Found a student dir"
            stu_name=$(basename "$stu_dir")
            stu_bin="$bin_dir/$stu_name"
            { build "$stu_bin" "$stu_dir" && all_judge score "$stu_bin"; } || \
            { echo 1>&2 "Failed to build student src: $stu_dir" && continue; }
            printf "%s\t%s\n" $stu_name $score
        fi
    done
}

judge
