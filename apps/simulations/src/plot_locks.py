import numpy as np
import matplotlib.pyplot as plt

# Time range: 0 to 12 months
time = np.linspace(0, 12, 100)

# Global constant for decay threshold
global_slope = 0.1  # Global slope that applies uniformly

# User contribution function: Starts at a specified amount and decays over a specified duration
def user_contribution(amount, duration, start_time, t, global_slope):
    # Initial weight
    initial_weight = amount * duration
    # Calculate the individual slope based on initial weight
    individual_slope = initial_weight / duration
    
    # Start and end of decay period
    decay_start = start_time
    decay_end = start_time + duration
    
    # Use piecewise to calculate the contribution for each time period
    return np.piecewise(
        t, 
        [
            t < decay_start,  # Before the decay starts
            (t >= decay_start) & (t <= decay_end),  # During the decay period
            t > decay_end  # After the decay ends
        ], 
        [
            0,  # No contribution before start
            lambda t: initial_weight - (individual_slope * (t - decay_start)) - global_slope * (t - decay_start),  # Combined individual and global decay
            10  # Constant contribution after decay
        ]
    )

# Define user contributions with individual slopes plus global slope
alice_contribution = user_contribution(10, 6, 0, time, global_slope)
bob_contribution = user_contribution(10, 6, 3, time, global_slope)
charlie_contribution = user_contribution(50, 1, 6, time, global_slope)

# Total adjusted contribution with global slope
total_contribution_adjusted = alice_contribution + bob_contribution + charlie_contribution

# Plotting the individual contributions and total slope with the adjusted behavior
plt.figure(figsize=(10, 6))

# Plot individual contributions
plt.plot(time, alice_contribution, label="Alice 10/6", linestyle="dotted", color='blue')
plt.plot(time, bob_contribution, label="Bob 10/6", linestyle="dotted", color='green')
plt.plot(time, charlie_contribution, label="Charlie 50/1", linestyle="dotted", color='orange')

# Plot total contribution
plt.plot(time, total_contribution_adjusted, label='Total Contribution', color='red', linewidth=2)

# Adding a horizontal line for the threshold
plt.axhline(y=80, color='purple', linestyle='dotted', label='Threshold')

# Adding labels and legend
plt.title('Initiative Support Over Time (With Global and Individual Slopes)')
plt.xlabel('Time (Months)')
plt.ylabel('Initiative Weight')
plt.legend()
plt.grid(True)

# Display the plot
plt.show()