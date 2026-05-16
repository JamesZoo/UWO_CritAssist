import Foundation

enum Fixtures {
    static var kungPaoScenario: Recipe {
        let rev1Ingredients = [
            Ingredient(name: "Boneless chicken thigh", quantity: "300 g"),
            Ingredient(name: "Roasted peanuts", quantity: "60 g"),
            Ingredient(name: "Dried red chilies", quantity: "8"),
            Ingredient(name: "Sichuan peppercorns", quantity: "1 tsp"),
            Ingredient(name: "Scallion whites", quantity: "3"),
            Ingredient(name: "Chinkiang vinegar", quantity: "2 tbsp"),
            Ingredient(name: "Light soy sauce", quantity: "1 tbsp"),
            Ingredient(name: "Sugar", quantity: "1 tbsp"),
            Ingredient(name: "Cornstarch", quantity: "1 tsp")
        ]
        let rev1Steps = [
            Step(index: 1, text: "Dice chicken and toss with cornstarch, salt, and a splash of soy.", technique: "velveting"),
            Step(index: 2, text: "Mix sauce: vinegar, soy, sugar, 2 tbsp water."),
            Step(index: 3, text: "Heat oil; sizzle chilies and peppercorns until fragrant."),
            Step(index: 4, text: "Add chicken; stir-fry over high heat until just cooked."),
            Step(index: 5, text: "Add scallions and peanuts; pour in sauce and toss to glaze.")
        ]
        let rev1 = Revision(
            index: 1,
            ingredients: rev1Ingredients,
            steps: rev1Steps,
            referenceStyle: "Sichuan home-style",
            rationale: "Initial summary from public Kung Pao recipes."
        )

        return Recipe(
            name: "宫爆鸡丁",
            summary: "Classic Sichuan stir-fry: diced chicken with peanuts in a sweet-sour-spicy sauce. Look for the balance: tingly heat, bright vinegar, restrained sugar.",
            revisions: [rev1]
        )
    }

    static var allScenarios: [Recipe] { [kungPaoScenario] }
}
