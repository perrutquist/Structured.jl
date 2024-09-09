## Another Example

A single-value `Option` (or `Enum`) can be used to force the AI to output certain constants, essentially making it give instructions to itself.

```julia
using Structured: system, user, assistant, response_format, get_choices, get_choice, Option
using OpenAI

struct Documentation
    language::Option{(:Markdown,)}
    content::String
end

struct Code
    language::Option{(:Julia,)}
    content::String
end

struct CodeExample
    documentation::Documentation
    code::Code
end

reply = OpenAI.create_chat(
    ENV["OPENAI_API_KEY"],
    "gpt-4o-2024-08-06",
    [ system => "The assistant is a skilled coder who replies to any request in JSON format",
      user => "Please show me a cool sorting algorithm." ],
    response_format = response_format(CodeExample),
)

choice = get_choice(CodeExample, reply) # Returns a Vector{MathReasoning} of length n

println(choice.documentation.content) 
println(choice.code.content)
```

## Example output (AI-generated sorting documentation and code)

```markdown
# QuickSort Algorithm

Quicksort is an efficient, recursive divide-and-conquer sorting algorithm. It's not a stable sort but is practical for many cases due to its average O(n log n) complexity. It works by selecting a 'pivot' element from the array and partitioning the other elements into two sub-arrays, according to whether they are less than or greater than the pivot. The sub-arrays are then sorted recursively.

## Key Steps:
1. Choose a pivot from the list.
2. Partition the list into two sub-arrays: elements less than the pivot and elements greater than the pivot.
3. Recursively apply the above steps to the sub-arrays.

This recursive nature ensures a clean and efficient sort, with its performance significantly reliant on the choice of the pivot (randomized or median approaches often work well). Quicksort is well-suited for sorting large datasets and is commonly used in many standard libraries.
```
```julia
# QuickSort implemented in Julia

function partition!(arr, low, high)
    pivot = arr[high]
    i = low - 1
    
    for j = low:(high - 1)
        if arr[j] <= pivot
            i += 1
            arr[i], arr[j] = arr[j], arr[i]
        end
    end
    arr[i + 1], arr[high] = arr[high], arr[i + 1]
    return i + 1
end

function quicksort!(arr, low, high)
    if low < high
        pi = partition!(arr, low, high)
        quicksort!(arr, low, pi - 1)
        quicksort!(arr, pi + 1, high)
    end
end

# Wrapper function for sorting
function sort_array(arr)
    quicksort!(arr, 1, length(arr))
    return arr
end

# Example usage
arr = [10, 7, 8, 9, 1, 5]
println("Original Array:", arr)
println("Sorted Array: ", sort_array(arr))
# Output: Sorted Array: [1, 5, 7, 8, 9, 10]
```

