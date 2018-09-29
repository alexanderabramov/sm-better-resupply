-- Debug
local log = log or function() end
local logf = logf or function() end
local try = try or function(f) f() end

-- Helper function to format a value with 3 significant figures with an SI scale prefix
local siPrefix = {"", "k", "M", "G", "T", "P", "E"}
local function formatAmount(amount)
    if not amount then
        return ""
    end

    -- Scale down to at most 3 sig figs
    local scale = 0
    while amount >= 1000 or amount <= -1000 do
        amount = amount / 10
        scale = scale + 1
    end

    -- Figure out which prefix to use and scale the value accordingly
    local si = siPrefix[1+(scale+2)/3]
    local sigFigs = (scale+2)/3*3 - scale
    amount = amount / 10.^sigFigs

    return string.format("%."..sigFigs.."f%s", amount, si)
end

function OnMsg.ClassesBuilt()
    -- Add a new column showing the colony's current supply of each item
    TemplateHelpers:InsertAfter("BetterResupply#cargo-current", 
        XTemplates.PropPayload, 
        function(t)
            return t.Id == "idAdd"
        end, 
        PlaceObj("XTemplateWindow", {
            "__class", "XText",
            "__condition", function() return not not UICity end,
            "Id", "idBetterResupplyCargoCurrent",
            "Padding", box(2, 2, 5, 2),
            "HAlign", "right",
            "VAlign", "center",
            "MinWidth", 60,
            "MaxWidth", 60,
            "TextFont", "PGResource",
            "TextColor", RGBA(255, 248, 233, 255),
            "RolloverTextColor", RGBA(255, 255, 255, 255),
            "WordWrap", false,
            "TextHAlign", "right",
            "TextVAlign", "center",
        })
    )

    -- Extend the cargo update function to also update the new column
    TemplateHelpers:Replace("BetterResupply#cargo-update",
        XTemplates.PropPayload,
        function(t)
            return t.name == "OnPropUpdate(self, context, prop_meta, value)"
        end,
        function(prev)
            local new = prev:Clone()
            new.func = function(self, context, prop_meta, value)
                prev.func(self, context, prop_meta, value)

                try(function()
                    if not UICity then return end
                    local id = prop_meta.id

                    local current = nil
                    local color = ""
                    if Resources[prop_meta.id] then
                        -- Compute usage statistics
                        local prod = ResourceOverviewObj:GetProducedYesterday(id)
                        local cons = ResourceOverviewObj:GetConsumedByConsumptionYesterday(id)
                        local maint = ResourceOverviewObj:GetEstimatedDailyMaintenance(id)
                        local avail = ResourceOverviewObj:GetAvailable(id)
                        local net = prod - cons - maint

                        -- Include this cargo in the supply
                        local obj = ResolvePropObj(context)
                        local item = RocketPayload_GetMeta(id)
                        avail = avail + obj:GetAmount(item) * const.ResourceScale

                        -- If net is negative, color code based on how long supplies + cargo will last
                        if net < 0 then
                            local runway = avail / -net
                            if runway < 5 then
                                color = "<color 255 0 0>"
                            elseif runway < 10 then
                                color = "<color 255 255 0>"
                            else
                                color = "<color 0 255 0>"
                            end
                        end

                        current = avail / const.ResourceScale
                    elseif DataInstances.BuildingTemplate[id] then
                        current = UICity:GetPrefabs(id)
                    else
                        local list = UICity and UICity.labels[id]
                        current = list and #list or nil
                    end

                    self.idBetterResupplyCargoCurrent:SetText(color..formatAmount(current))
                end)
            end
            return new
        end
    )
end

-- Extend the cargo tooltip to include usage information for resources
local _RocketPayloadObject_GetRollover = RocketPayloadObject.GetRollover
function RocketPayloadObject:GetRollover(id)
    local ret = _RocketPayloadObject_GetRollover(self, id)
    try(function()
        if not UICity then return end

        if ret and ret.descr and Resources[id] then 
            -- Compute usage statistics
            local prod = ResourceOverviewObj:GetProducedYesterday(id)
            local cons = ResourceOverviewObj:GetConsumedByConsumptionYesterday(id)
            local maint = ResourceOverviewObj:GetEstimatedDailyMaintenance(id)
            local avail = ResourceOverviewObj:GetAvailable(id)
            local net = prod - cons - maint

            -- Preformat some common stuff
            local blank = "<newline><newline>"
            local right = " <right><"..string.lower(id).."(value)><left><newline>"
            local netRight = (net < 0 and "<color 255 0 0>" or "<color 0 255 0>")..right.."<color 255 255 255>"

            -- Extend the description string with usage info
            ret.descr = ret.descr..
                blank..
                T{"Production"..right, name = id, value = prod}..
                T{"Consumption"..right, name = id, value = cons}..
                T{"Maintenance"..right,name = id, value = maint}..
                blank..
                T{"Net Change"..netRight, name = id, value = net}

            -- If net is negative, add how long current supplies will last
            if net < 0 then
                ret.descr = ret.descr..
                    blank..
                    T{"Runway <right><value> Sols<left><newline>", name = id, value = avail / -net}
            end
        end
    end)
    return ret
end
