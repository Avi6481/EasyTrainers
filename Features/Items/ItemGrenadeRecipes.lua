local RecipeBook = require("Features/Items/RecipeBook")

local ItemGrenadeRecipes = {}

local IDS = {
    "RecipeGrenadeIncendiaryRegular",
    "RecipeGrenadeIncendiarySticky",
    "RecipeGrenadeIncendiaryHoming",
    "RecipeGrenadeEMPRegular",
    "RecipeGrenadeEMPSticky",
    "RecipeGrenadeEMPHoming",
    "RecipeGrenadeFragRegular",
    "RecipeGrenadeFragSticky",
    "RecipeGrenadeFragHoming",
    "RecipeGrenadeCuttingRegular",
    "RecipeGrenadeBiohazardRegular",
    "RecipeGrenadeBiohazardHoming",
    "RecipeGrenadeOzobsNose",
    "RecipeGrenadeReconRegular",
    "RecipeGrenadeReconSticky",
    "RecipeGrenadeFlashRegular",
    "RecipeGrenadeFlashHoming",
    "RecipeGrenadeIncendiaryRare",
    "RecipeGrenadeEMPRare",
    "RecipeGrenadeReconRare",
    "RecipeGrenadeSmokeRare",
    "RecipeGrenadeEMPUncommon",
    "RecipeGrenadeFragUncommon",
    "RecipeGrenadeSmokeRegular",
    "RecipeGrenadeFlashUncommon",
    "RecipeGrenadeFragEpic",
    "RecipeGrenadeSmokeEpic",
    "RecipeGrenadeFlashEpic",
    "RecipeGrenadeIncendiaryLegendary",
    "RecipeGrenadeEMPLegendary",
    "RecipeGrenadeBiohazardLegendary",
    "RecipeGrenadeReconLegendary",
    "RecipeGrenadeSmokeLegendary",
    "RecipeGrenadeFlashLegendary"
}

function ItemGrenadeRecipes.GiveAllGrenadeRecipes(seen)
    return RecipeBook.Unlock(IDS, seen)
end

return ItemGrenadeRecipes
