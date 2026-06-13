function inspect {
    if [[ ${(t)${(P)1}} == "association" ]]; then
        print "$1 (${(t)${(P)1}}):"
        for key val in "${(@kv)${(P)1}}"; do
            print "\t$key -> $val"
        done
    elif [[ ${(t)${(P)1}} == "array" ]]; then
        print "$1 (${(t)${(P)1}}):"
        for val in "${(@)${(P)1}}"; do
            print "\t$val"
        done
    else
        print "$1 (${(t)${(P)1}}): ${(P)1}"
    fi
}
