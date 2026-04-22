function quicksort<T>(arr: T[]): T[] {
    if (arr.length <= 1) {
        return arr;
    }

    const pivot = arr[Math.floor(arr.length / 2)];
    const left: T[] = [];
    const right: T[] = [];
    const equal: T[] = [];

    for (const element of arr) {
        if (element < pivot) {
            left.push(element);
        } else if (element > pivot) {
            right.push(element);
        } else {
            equal.push(element);
        }
    }

    return [...quicksort(left), ...equal, ...quicksort(right)];
}

// Example usage
const numbers = [64, 34, 25, 12, 22, 11, 90, 5, 77, 30];
const strings = ['banana', 'apple', 'orange', 'grape', 'cherry'];

console.log('Original numbers:', numbers);
const sortedNumbers = quicksort(numbers);
console.log('Sorted numbers:', sortedNumbers);

console.log('\nOriginal strings:', strings);
const sortedStrings = quicksort(strings);
console.log('Sorted strings:', sortedStrings);

// In-place quicksort implementation (more memory efficient)
function quicksortInPlace<T>(arr: T[], left: number = 0, right: number = arr.length - 1): T[] {
    if (left < right) {
        const pivotIndex = partition(arr, left, right);
        quicksortInPlace(arr, left, pivotIndex - 1);
        quicksortInPlace(arr, pivotIndex + 1, right);
    }
    return arr;
}

function partition<T>(arr: T[], left: number, right: number): number {
    const pivot = arr[right];
    let i = left - 1;

    for (let j = left; j < right; j++) {
        if (arr[j] <= pivot) {
            i++;
            [arr[i], arr[j]] = [arr[j], arr[i]]; // Swap
        }
    }
    
    [arr[i + 1], arr[right]] = [arr[right], arr[i + 1]]; // Place pivot in correct position
    return i + 1;
}

// Example of in-place quicksort
const numbersForInPlace = [64, 34, 25, 12, 22, 11, 90, 5, 77, 30];
console.log('\n\nIn-place quicksort:');
console.log('Original:', [...numbersForInPlace]);
quicksortInPlace(numbersForInPlace);
console.log('Sorted:  ', numbersForInPlace);