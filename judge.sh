#! /bin/bash
eps=1e-6
float_scale=6
stu_input="/tmp/judge.stu_input"
stu_output="/tmp/judge.stu_output"
data_dir="testcases/"
src_dir="src/"
bin_dir="bin/"
mem_limit="$((1024 * 1024))"
time_limit="20s"
#datasets=('exact 0' 'extra 0' 'inexact 1' 'weak 0')
datasets=('exact 0' 'simple 0' 'inexact 1' 'extra 0')
mkdir -p "$bin_dir"
mkdir -p "$src_dir"

function test_exp {
    local exp=$1
    local val=$2
    echo "exp: \"$exp\", val: \"$val\""
#    [[ $(guile -c "(display (< (magnitude (- $exp $val)) $eps))") == "#t" ]]
    [[ $(guile -c "(display 
    (let ((d (magnitude (- $exp $val)))
    (m0 (magnitude $val)))
    (if (> m0 $eps) (set! d (min d (/ d m0))))
    (< d $eps)))") == "#t" ]]
}

function run {
    local stu_prog="$1"
    shift 1
    echo "** Running $stu_prog.. ***" >> judge_run.log
    (ulimit -v $mem_limit && \
        timeout -k 0 "$time_limit" "$stu_prog" $@ 2>> judge_run.log)
    echo "** Done ***" >> judge_run.log
}

function special_judge {
    local datafile="$1"
    local stu_prog="$2"
    local lvl=0
    local buff=""
    local exps=()
    shift 2
    echo 1>&2 "*** Special Judge: $datafile ***"
    while IFS="" read -rn 1 ch; do
        buff+="${ch:-$'\n'}"
        if [[ "$ch" == "(" ]]; then
            let lvl++
        elif [[ "$ch" == ")" ]]; then
            let lvl--
            if [[ "$lvl" -eq 0 && -n "$buff" ]]; then
                exps+=("$buff")
                #echo 1>&2 "Found expression: $buff"
                buff=""
            fi
        fi
    done < "$datafile"
    IFS=$'\n'
    for exp in "${exps[@]}"
    do 
        echo "(display $exp)"
        echo "(display \"\n\")"
    done > "$stu_input"
    echo "Special Judge: $stu_intput" >> judge_run.log
    res=($(run "$stu_prog" < "$stu_input"))
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
    local stu_prog="$2"
    echo 1>&2 "*** Judge: $datafile ***"
    echo "Special Judge: $datafile" >> judge_run.log
    run "$stu_prog" < "$datafile" > "$stu_output"
    guile -s "$datafile" | diff - "$stu_output" > /dev/null #>> judge.log
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
    local stu_prog="$2"
    score=()
    for dataset in "${datasets[@]}"; do
        local d=($dataset)
        local correct=0
        local j
        for c in "$data_dir/${d[0]}/"*.scm; do
            if (("${d[0]}" == 1)); then
                j=special_judge
            else
                j=fullcmp_judge
            fi
            ($j "$c" "$stu_prog") && echo 1>&2 "Correct" && ((correct++)) 
        done
        score+=($correct)
    done
    eval $__score="$score"
}

function build {
    local stu_bin="$1"
    local stu_dir="$2"
#    g++ -o calc -std=gnu++0x -m64 $(find . -name "*.cpp") 
    g++ -DGMP_SUPPORT -lgmp -o "$stu_bin" -std=gnu++0x -m64 $(find "$stu_dir" -name "*.cpp")
}

function judge {
    local src_dir="$1"
    local bin_dir="$2"
    printf "%s" 'ID'
    for dataset in "${datasets[@]}"; do
        local d=($dataset)
        printf "\t%s" "${d[0]}"
    done
    printf "\n"
    for stu_dir in "$src_dir"/*; do
        echo 1>&2 "$stu_dir"
        if [ -d "$stu_dir" ]; then
            echo 1>&2 "Found a student dir"
            stu_name=$(basename "$stu_dir")
            stu_bin="$bin_dir/$stu_name"
            { build "$stu_bin" "$stu_dir" && all_judge score "$stu_bin"; } || \
            { echo 1>&2 "Failed to build student src: $stu_dir" && continue; }
            printf "%s" $stu_name
            for s in "${score[@]}"; do
                printf "\t\t%s" $s
            done
            printf "\n"
        fi
    done
}

judge "$src_dir" "$bin_dir" > result
