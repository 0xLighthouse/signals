import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

from discourse import get_topics

# Define the forum URL and the file path
url = 'https://forum.arbitrum.foundation/c/proposals/7.json'
# Define the file path dynamically based on the script's location
file_path = os.path.join(os.path.dirname(__file__), 'arbitrum-proposals.json')

# Get topics
topics = get_topics(url, file_path)

# Convert the topics to a DataFrame
df = pd.DataFrame(topics)

# Convert 'created_at' and 'last_posted_at' to datetime
df['created_at'] = pd.to_datetime(df['created_at'])
df['last_posted_at'] = pd.to_datetime(df['last_posted_at'])

# Extract hour and day of the week
df['hour'] = df['created_at'].dt.hour
df['day_of_week'] = df['created_at'].dt.day_name()

# Create a pivot table
pivot_table = df.pivot_table(index='day_of_week', columns='hour', values='id', aggfunc='count', fill_value=0)

# Reorder days of the week
days_order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
pivot_table = pivot_table.reindex(days_order)

# Plot the heatmap with inverted axes
plt.figure(figsize=(12, 8))
sns.heatmap(pivot_table.T, cmap='YlGnBu', annot=True, fmt='d')
plt.title('Heatmap of Post Creation Times')
plt.xlabel('Day of Week')
plt.ylabel('Hour of Day')
plt.show()
