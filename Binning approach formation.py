# Based on the business context we created - predicting number of viewers would
# be great, but popularity group would also be fine and easier to predict.
# How do we bin into the groups? The challenge is that there way too many unpopular animes,
# and we don't want to create unbalanced classes.

import pandas as pd
from pandas import read_csv


# loading dastaset
df = read_csv('/Users/vorontsov/Downloads/anime_wpre.csv') # change for your correct path

# looking at quantiles - first idea
quantiles = df['members'].quantile([0.25, 0.5, 0.75])
print(quantiles)

# makes prediction complex, no point to make more groups since no client requirements are given
#quantiles_to_experiment = df['members'].quantile([0.2, 0.4, 0.6, 0.8])
#print(quantiles_to_tune)

# Creating bins based on quartiles
def assign_group(x, quantiles):
    if x <= quantiles.iloc[0]:
        return '1st quartile'
    elif x <= quantiles.iloc[1]:
        return '2nd quartile'
    elif x <= quantiles.iloc[2]:
        return '3rd quartile'
    else:
        return '4th quartile'

# Creating columns
df['popularity_group'] = df['members'].apply(lambda x: assign_group(x, quantiles))

print(df[['members', 'popularity_group']].head(10))
print(df['popularity_group'].value_counts())

# Making it more like in real data, but marketing-appropriate (good borders between groups)and not unbalanced
def assign_group2(x):
    if x <= 500: # 0,25 guartile + 250 = 540 -> 500
        return '0-500'  # Наименьшая группа
    elif x <= 5000: # median + 250 = 2157 -> 2000
        return '500-5000'
    elif x <= 30000: # 0,75 guartile + 250 = 16449 -> 15000
        return '5000-30000'
    else:
        return '>30000'  # Наибольшая группа

df['new_popularity_group'] = df['members'].apply(lambda x: assign_group2(x))

print(df['new_popularity_group'].value_counts())

# Visualising distributions for understanding

import matplotlib.pyplot as plt

ordered_groups = ['4th quartile', '3rd quartile', '2nd quartile', '1st quartile']

fig, axes = plt.subplots(nrows=2, ncols=1, figsize=(10, 8))

df_mod = df[df['members'] < 50000]
x = [df_mod[df_mod['popularity_group'] == group]['members'] for group in ordered_groups]
axes[0].hist(x, bins=1000, histtype='stepfilled', stacked=True, label=ordered_groups, alpha=0.75)
axes[0].set_title('Members frequency by Original Popularity Group')
axes[0].set_xlabel('Members')
axes[0].set_ylabel('Frequency')
axes[0].set_xlim(0, 40000)
axes[0].set_ylim(0, 400)
axes[0].legend()


ordered_groups2 = ['>30000', '5000-30000', '500-5000', '0-500']

df_mod2 = df[df['members'] < 50000]
x = [df_mod2[df_mod2['new_popularity_group'] == group]['members'] for group in ordered_groups2]
axes[1].hist(x, bins=1000, histtype='stepfilled', stacked=True, label=ordered_groups2, alpha=0.75)
axes[1].set_title('Members frequency by Adjusted Popularity Group')
axes[1].set_xlabel('Members')
axes[1].set_ylabel('Frequency')
axes[1].set_xlim(0, 40000)
axes[1].set_ylim(0, 400)
axes[1].legend()

plt.tight_layout()
plt.show()

df.drop('popularity_group', axis=1, inplace=True)

#df.to_csv('/Users/vorontsov/Desktop/DDS/anime_ml_140123.csv', index = False)
