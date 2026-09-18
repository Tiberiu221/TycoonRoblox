--!strict
-- [D62] SALTUL SCURT al unui lucru care tocmai a crescut (un nivel, o treapta, o cifra din meniu): se umfla si revine,
-- cu o mica depasire. Un singur UIScale pe obiect: daca are deja unul (platformele il au, pentru "strivirea" de la
-- cumparare), se foloseste acela -- doua UIScale pe acelasi obiect nu se aduna, castiga unul la intamplare.
local TweenService = game:GetService("TweenService")

local Pop = {}

function Pop.play(target: GuiObject, from: number?, seconds: number?)
    local scale = target:FindFirstChildOfClass("UIScale")
    if scale == nil then
        scale = Instance.new("UIScale")
        scale.Parent = target
    end
    scale.Scale = from or 1.14
    TweenService:Create(
        scale,
        TweenInfo.new(seconds or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    ):Play()
end

return Pop
