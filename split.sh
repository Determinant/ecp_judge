#! /bin/bash
datafile="$1"
num="$2"
lvl=0
buff=""
exps=()
shift 2
function exp_flush {
    if [[ "$lvl" -eq 0 && -n "$buff" ]]; then
        exps+=("$buff")
        #echo 1>&2 "Found expression: $buff"
        buff=""
    fi
}
function isspace {
    [[ "${ch:-$'\n'}" == $'\n' || "$ch" == ' ' || "$ch" == $'\t' || "$ch" == $'\t' ]]
}
while IFS="" read -rn 1 ch; do
    if [[ !("$lvl" -eq 0) ]] || ! isspace "$ch"; then
        buff+="${ch:-$'\n'}"
    fi
    if [[ "$ch" == "(" ]]; then
        let lvl++
    elif [[ "$ch" == ")" ]]; then
        let lvl--
        exp_flush
    elif [[ "$lvl" -eq 0 ]] && isspace "$ch"; then
        exp_flush
    fi
done < "$datafile"
echo "Buff: $buff"
IFS=$'\n'

cnt=0
fcnt=0
bexp=()
function flush {
    fname="$(echo $datafile | sed 's/\(.*\)\.scm/\1/g')-${fcnt}.scm"
    echo $fname
    for e in "${bexp[@]}"; do
        echo "$e"
    done > $fname
    let fcnt++
    cnt=0
    bexp=()
}
for exp in "${exps[@]}"; do
    let cnt++
    echo "Exp: $exp"
    bexp+=("$exp")
    if (($cnt == $num)); then
        flush
    fi
done
if (($cnt != 0)); then
    flush
fi
