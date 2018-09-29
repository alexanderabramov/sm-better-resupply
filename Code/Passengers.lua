-- Debug
local log = log or function() end
local logf = logf or function() end
local try = try or function(f) f() end

function OnMsg.ClassesBuilt()
    -- Add UI on the left of the passenger resupply screen for summary info
    TemplateHelpers:InsertAfter("BetterResupply#passenger-summary",
        XTemplates.ResupplyPassengers,
        function(t)
            return t.Id == "idContent"
        end,
        PlaceObj("XTemplateWindow", {
            "Id", "idBetterResupplySummary",
            "Visible", false,
            "Margins", box(0, -65, 0, -180),
            "Padding", box(0, 252+65, 0, 0),
            "HAlign", "left",
            "LayoutMethod", "HList",
            "Background", RGBA(0, 0, 0, 64),
        }, {
            PlaceObj("XTemplateWindow", {
                "Margins", box(65, 0, 45, 0),
            }, {
                PlaceObj("XTemplateWindow", {
                    "__class", "XLabel",
                    "Padding", box(2, 2, 2, 2),
                    "Dock", "top",
                    "HAlign", "left",
                    "TextFont", "PGMissionDescrTitle",
                    "TextColor", RGBA(96, 135, 185, 255),
                    "Translate", true,
                    "Text", T{"Interests"},
                }),
                PlaceObj("XTemplateWindow", {
                    "__class", "XText",
                    "Id", "idBetterResupplyInterests",
                    "Padding", box(2, 2, 5, 2),
                    "Dock", "top",
                    "HAlign", "left",
                    "MinWidth", 200,
                    "MaxWidth", 200,
                    "TextFont", "PGResource",
                    "TextColor", RGBA(255, 248, 233, 255),
                    "RolloverTextColor", RGBA(255, 255, 255, 255),
                    "WordWrap", false,
                    "TextHAlign", "left",
                }),
            }),
            PlaceObj("XTemplateWindow", {
                "Margins", box(45, 0, 65, 0),
            }, {
                PlaceObj("XTemplateWindow", {
                    "__class", "XLabel",
                    "Padding", box(2, 2, 2, 2),
                    "Dock", "top",
                    "HAlign", "left",
                    "TextFont", "PGMissionDescrTitle",
                    "TextColor", RGBA(96, 135, 185, 255),
                    "Translate", true,
                    "Text", T{"Demographics"},
                }),
                PlaceObj("XTemplateWindow", {
                    "__class", "XText",
                    "Id", "idBetterResupplyDemographics",
                    "Padding", box(2, 2, 5, 2),
                    "Dock", "top",
                    "HAlign", "left",
                    "MinWidth", 200,
                    "MaxWidth", 200,
                    "TextFont", "PGResource",
                    "TextColor", RGBA(255, 248, 233, 255),
                    "RolloverTextColor", RGBA(255, 255, 255, 255),
                    "WordWrap", false,
                    "TextHAlign", "left",
                })
            })
        })
    )

    -- Don't clear the approved list when opening the review screen from the categories list
    TemplateHelpers:Replace("BetterResupply#categories-review",
        XTemplates.ResupplyPassengers,
        function(t, p)
            return t.ActionId == "review" and p.mode == "traitCategories"
        end,
        function(prev)
            local new = prev:Clone()
            new.OnAction = function(self, host, win, toggled)
                local obj = ResolvePropObj(host.context)
                obj.approved_applicants = obj.approved_applicants or {}
                host:SetMode("review")
            end
            return new
        end
    )

    -- Don't clear the approved list when opening the review screen from the items list
    TemplateHelpers:Replace("BetterResupply#items-review",
        XTemplates.ResupplyPassengers,
        function(t, p)
            return t.ActionId == "review" and p.mode == "items"
        end,
        function(prev)
            local new = prev:Clone()
            new.OnAction = function(self, host, win, toggled)
                local obj = ResolvePropObj(host.context)
                obj.approved_applicants = obj.approved_applicants or {}
                host:SetMode("review")
            end
            return new
        end
    )

    -- Don't clear the approved list when leaving the review screen
    TemplateHelpers:Replace("BetterResupply#review-back",
        XTemplates.ResupplyPassengers,
        function(t, p)
            return t.ActionId == "back" and p.mode == "review"
        end,
        function(prev)
            local new = prev:Clone()
            new.OnAction = function(self, host, win, toggled)
                SetBackDialogMode(host)
            end
            return new
        end
    )

    -- Recompute the summary stats when an item in the review list is clicked
    TemplateHelpers:Replace("BetterResupply#review-click",
        XTemplates.PropApplicant, 
        function(t, p)
            return t.name == "OnMouseButtonDown(self, pos, button)" and p.Id == "idPositive"
        end,
        function(prev)
            local new = prev:Clone()
            new.func = function(self, pos, button)
                local ret = prev.func(self, pos, button)

                try(function()
                    -- find "idBetterResupplySummary"
                    local node = self
                    while node and not node.idBetterResupplySummary do
                        node = node.parent
                    end
                    if not node then
                        log("idBetterResupplySummary not found")
                        return
                    end

                    -- calculate count of each trait
                    local obj = ResolvePropObj(self.parent.context)
                    local traits = {}
                    for applicant, _ in pairs(obj.approved_applicants) do
                        local unit_traits = applicant[1].traits
                        if unit_traits.Senior and not g_SeniorsCanWork then
                            traits.Senior = (traits.Senior or 0) + 1
                        else
                            for trait, _ in pairs(unit_traits) do
                                traits[trait] = (traits[trait] or 0) + 1
                            end
                        end
                    end

                    -- count application interests
                    local interests = {}
                    for applicant, _ in pairs(obj.approved_applicants) do
                        for _, int in ipairs(GetInterests(applicant[1])) do
                            interests[int] = (interests[int] or 0) + 1
                        end
                    end

                    local summary = ""

                    -- add age/spec/gender summary
                    local categories = {"Age Group", "Specialization", "Gender"}
                    for _, cat in ipairs(categories) do
                        local added = false
                        for _, trait in ipairs(DataInstances.Trait) do
                            local count = traits[trait.name]
                            if count and cat == trait.category and not g_HiddenTraits[trait.name] 
                                    and IsTraitAvailable(trait, UICity, "unlocked") then
                                summary = summary..trait.display_name..
                                    string.format("<right>%d<left><newline>", traits[trait.name])
                                added = true
                            end
                        end
                        if added then
                            summary = summary.."<newline><newline>"
                        end
                    end
                    
                    -- add rare traits
                    local added = false
                    for _, trait in ipairs(DataInstances.Trait) do
                        local count = traits[trait.name]
                        if count and trait.rare and not g_HiddenTraits[trait.name] 
                                and IsTraitAvailable(trait, UICity, "unlocked") then
                            summary = summary..trait.display_name..
                                string.format("<right>%d<left><newline>", count)
                        end
                    end
                    if added then
                        summary = summary.."<newline><newline>"
                    end

                    node.idBetterResupplySummary:SetVisible(summary ~= "")
                    node.idBetterResupplyDemographics:SetText(T{summary})
                    summary = ""

                    -- add interested
                    for _, int in ipairs(ServiceInterestsList) do
                        local n = interests[int]
                        if n then
                            summary = summary..Interests[int].display_name..
                                string.format("<right>%d<left><newline>", n)
                        end
                    end

                    node.idBetterResupplyInterests:SetText(T{summary})
                end)

                return ret
            end
            return new
        end
    )

    -- Allow individual traits to be clicks to review those type of applicants
    TemplateHelpers:Replace("BetterResupply#prop-click",
        XTemplates.PropTrait,
        function(t,p)
            return t.name == "OnMouseButtonDown(self, pos, button)" and p.__template ~= "PropCheckBoxValue"
        end,
        function(prev)
            local new = prev:Clone()
            new.func = function(self, pos, button)
                XPropControl.OnMouseButtonDown(self, pos, button)
                if button == "L" then
                    local obj = ResolvePropObj(self.context)
                    if self.prop_meta.submenu then
                        obj:CountApprovedColonistsForCategory(self.prop_meta.id)
                        SetDialogMode(self, "items", self.prop_meta)
                    elseif not obj.dome and self.prop_meta.value ~= "all" then
                        obj.temp_filter = {[self.prop_meta.value] = true}
                        obj.approved_applicants = obj.approved_applicants or {}
                        SetDialogMode(self, "review", self.prop_meta)
                    end
                    return "break"
                end
            end
            return new
        end
    )

    -- Style applications that wouldn't normally be shown differently
    TemplateHelpers:Replace("ButterResupply#applicant-style",
        XTemplates.PropApplicant,
        function(t)
            return t.name == "OnPropUpdate(self, context, prop_meta, value)"
        end,
        function(prev)
            local new = prev:Clone()
            new.func = function(self, context, prop_meta, value)
                prev.func(self, context, prop_meta, value)

                try(function()
                    log(prop_meta)
                    if prop_meta.base_eval < 0 then
                        self.idName:SetTextColor(RGBA(255, 0, 0, 128))
                        self.idName:SetRolloverTextColor(RGBA(255, 192, 192, 128))
                    end
                end)
            end
            return new
        end
    )
end

local _TraitsObject_GetReviewColonists = TraitsObject.GetReviewColonists
function TraitsObject:GetReviewColonists()
    local all
    try(function()
        local filter = self.filter
        local temp_filter = self.temp_filter

        -- If a temp filter was set, clear it
        self.temp_filter = nil

        -- Clear the filter temporarily so we can get data for all applicants
        self.filter = empty_table
        all = _TraitsObject_GetReviewColonists(self)
        self.filter = filter

        -- Score colonists and remove any negative scores that aren't already selected
        for i = #all, 1, -1 do
            -- Score the applicant
            local applicant = all[i].applicant
            local traits = applicant[1].traits
            local eval = TraitFilterColonist(filter, traits)
            all[i].base_eval = eval

            -- Adjust the score if there's a temp filter to score all matches above all non-matches
            local temp_eval = temp_filter and (2*TraitFilterColonist(temp_filter, traits) - 1) or 0
            eval = eval + 10000 * temp_eval
            all[i].eval = eval

            -- Remove any applicants with a negative score if they aren't already approved
            if eval < 0 and not self.approved_applicants[applicant] then
                table.remove(all, i)
            end
        end

        -- Sort the remainder by score and return them
        table.sortby_field_descending(all, "eval")
    end)
    return all
end
