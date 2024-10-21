#!/bin/bash

BASE_URL="http://localhost:3000"
LOG_FILE="test_results.log"
BENCHMARK_FILE="performance_benchmark.csv"

# Array of package and version combinations to test
PACKAGES=(
    "react/16.13.0"
    "lodash/4.17.21"
    "express/4.17.1"
    "axios/0.21.1"
    "@angular/core/12.0.0"
    "vue/3.0.11"
    "webpack/5.37.0"
    "typescript/4.2.4"
    "moment/2.29.1"
    "redux/4.1.0"
    "jquery/3.6.0"
    "rxjs/7.0.0"
    "next/10.2.0"
    "styled-components/5.3.0"
)

# Initialize log and benchmark files
echo "Timestamp,Package,Round,HTTP Status,Response Time (ms)" > "$BENCHMARK_FILE"
echo "Test Results - $(date)" > "$LOG_FILE"

test_package() {
    local pkg=$1
    local round=$2
    echo "Testing package: $pkg (Round $round)" | tee -a "$LOG_FILE"

    START_TIME=$(date +%s.%N)
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/api_response.json "$BASE_URL/package/$pkg")
    END_TIME=$(date +%s.%N)

    RESPONSE_TIME=$(echo "$END_TIME - $START_TIME" | bc | awk '{printf "%.0f", $1 * 1000}')

    echo "HTTP Status: $RESPONSE" | tee -a "$LOG_FILE"
    echo "Response Time: ${RESPONSE_TIME}ms" | tee -a "$LOG_FILE"

    echo "$(date +"%Y-%m-%d %H:%M:%S"),$pkg,$round,$RESPONSE,$RESPONSE_TIME" >> "$BENCHMARK_FILE"

    # Validate JSON response
    if jq empty /tmp/api_response.json 2>/dev/null; then
        echo "Response is valid JSON" | tee -a "$LOG_FILE"
        echo "Response Body:" | tee -a "$LOG_FILE"
        jq . /tmp/api_response.json | tee -a "$LOG_FILE"
    else
        echo "Error: Invalid JSON response" | tee -a "$LOG_FILE"
    fi

    # Check for specific fields in the response
    if jq -e '.name and .version and .dependencies' /tmp/api_response.json >/dev/null; then
        echo "Response contains required fields (name, version, dependencies)" | tee -a "$LOG_FILE"
    else
        echo "Error: Response is missing required fields" | tee -a "$LOG_FILE"
    fi

    echo "----------------------------------------" | tee -a "$LOG_FILE"
}

# Run two rounds of tests
for round in 1 2; do
    echo "Round $round" | tee -a "$LOG_FILE"
    for pkg in "${PACKAGES[@]}"; do
        test_package "$pkg" "$round"
    done
done

# Generate performance summary
echo "Performance Summary:" | tee -a "$LOG_FILE"
awk -F',' '
    $3 == 1 { sum1 += $5; count1++ }
    $3 == 2 { sum2 += $5; count2++ }
    END {
        print "Round 1 Average Response Time: " sum1/count1 " ms"
        print "Round 2 Average Response Time: " sum2/count2 " ms"
        print "Performance Improvement: " (sum1/count1 - sum2/count2)/(sum1/count1) * 100 "%"
    }
' "$BENCHMARK_FILE" | tee -a "$LOG_FILE"

echo "Test completed. Results saved in $LOG_FILE and $BENCHMARK_FILE"
