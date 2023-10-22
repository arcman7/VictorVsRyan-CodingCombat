package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"strconv"
)

func main() {
	f, err := os.Open("../data/custom_1988_2020.csv")
	if err != nil {
		panic(err)
	}
	defer f.Close()

	r := csv.NewReader(f)

	type Key struct {
		Year    string
		Country string
	}

	totals := make(map[Key]int)

	for {
		record, err := r.Read()
		if err != nil {
			if err == io.EOF {
				break
			}
			panic(err)
		}
		if record[1] != "1" {
			continue
		}
		value, err := strconv.Atoi(record[7])
		if err != nil {
			panic(err)
		}
		totals[Key{
			Year:    record[0][:4],
			Country: record[2],
		}] += value
	}

	var bestKey Key
	var bestValue int
	for k, v := range totals {
		if v > bestValue {
			bestKey = k
			bestValue = v
		}
	}

	fmt.Printf("Japan -> %v in %v, total value: %v\n", bestKey.Country, bestKey.Year, bestValue)
}
