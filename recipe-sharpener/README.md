# recipe-sharpener

A small CLI that "sharpens" a recipe: strips filler words, collapses
whitespace, and renumbers the steps so the instructions read tighter.

## Usage

```sh
python recipe_sharpener.py path/to/recipe.txt
# or pipe in
cat recipe.txt | python recipe_sharpener.py
```

## Input format

Plain text. An optional title on the first line, then an `Ingredients`
section and a `Steps` (or `Instructions`/`Directions`) section:

```
Banana Bread

Ingredients:
- 3 ripe bananas
- 1/2 cup butter
- 3/4 cup sugar

Steps:
1. Just go ahead and preheat the oven to 350F.
2. You'll really want to mash the bananas in a bowl.
3. Simply mix everything together and bake for 60 minutes.
```

Run through the sharpener and the steps come out as terse imperatives
with the filler removed.
