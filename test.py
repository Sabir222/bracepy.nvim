# Test Python file for bracepy plugin
# This file demonstrates various Python constructs that will show virtual braces


def hello_world(name):
    """A simple function to demonstrate function braces."""
    print(f"Hello, {name}!")
    for i in range(5):
        if i % 2 == 0:
            print(f"{i} is even")
        else:
            print(f"{i} is odd")
    return "Completed"


class Greeter:
    """A simple class to demonstrate class braces."""

    def __init__(self, greeting="Hello"):
        self.greeting = greeting

    def greet(self, name):
        """Method to greet someone."""
        try:
            result = self._format_greeting(name)
            print(result)
        except Exception as e:
            print(f"Error: {e}")

    def _format_greeting(self, name):
        """Private method to format greeting."""
        if name:
            return f"{self.greeting}, {name}!"
        else:
            return f"{self.greeting}!"


def calculate_sum(numbers):
    """Function to demonstrate loops and conditionals."""
    total = 0
    for num in numbers:
        if num > 0:
            total += num
        elif num < 0:
            total -= abs(num)
    return total


def process_data(data):
    """Function showing exception handling."""
    try:
        result = []
        for item in data:
            if isinstance(item, str):
                result.append(item.upper())
            else:
                result.append(str(item))
        return result
    except TypeError:
        print("Invalid data type provided")
        return []
    finally:
        print("Processing completed")


# Example usage
if __name__ == "__main__":
    greeter = Greeter()
    greeter.greet("World")

    numbers = [1, -2, 3, -4, 5]
    sum_result = calculate_sum(numbers)
    print(f"Sum: {sum_result}")

    data = ["hello", 42, "world"]
    processed = process_data(data)
    print(processed)

