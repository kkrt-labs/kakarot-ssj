import re


def process_logs(logs):
    current_address = None
    previous_gas = None
    accumulated_gas = 0

    pattern = re.compile(r"Address (\d+), gas left in call (\d+)")

    for line in logs.split("\n"):
        match = pattern.search(line)
        if match:
            address, gas_left = match.groups()
            gas_left = int(gas_left)

            if address != current_address:
                if current_address is not None:
                    print(
                        f"Total gas used for {hex(int(current_address))}: {accumulated_gas}"
                    )
                current_address = address
                previous_gas = gas_left
                accumulated_gas = 0
            else:
                gas_used = previous_gas - gas_left
                accumulated_gas += gas_used
                print(
                    f"Gas used in step for {hex(int(current_address))}: {gas_used} (Total: {accumulated_gas})"
                )
                previous_gas = gas_left

    if current_address is not None:
        print(f"Total gas used for {hex(int(current_address))}: {accumulated_gas}")


# Example usage
logs = """
Address 1169201309864722334562947866173026415724746034380, gas left in call 79978528
Address 1169201309864722334562947866173026415724746034380, gas left in call 79978525
"""

process_logs(logs)
