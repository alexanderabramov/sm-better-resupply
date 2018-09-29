local VERSION = 1

-- Preserve the tracked set between reloads
TemplateHelpers = TemplateHelpers or {v = VERSION, tracked = {}}

-- Upgrade to latest version if multiple versions are bundled with different mods
if TemplateHelpers.v <= VERSION then
    TemplateHelpers.v = VERSION

    -- DFS of the template for a node matching selector
    function TemplateHelpers:Find(template, selector)
        for i, child in ipairs(template) do
            if child then
                -- Check direct decendent for a match
                if selector(child, template) then
                    return child, template, i
                end
                -- Check children of decendent
                local result, parent, idx = self:Find(child, selector)
                if result then
                    return result, parent, idx
                end
            end
        end

        -- Not found
        return nil, nil, nil
    end

    function TemplateHelpers:InsertBefore(id, template, selector, item)
        self:Insert(id, template, selector, -1, item)
    end

    function TemplateHelpers:InsertAfter(id, template, selector, item)
        self:Insert(id, template, selector, 1, item)
    end

    function TemplateHelpers:Replace(id, template, selector, item)
        self:Insert(id, template, selector, 0, item)
    end

    function TemplateHelpers:Insert(id, template, selector, offset, item)
        -- Remove any old versions in case of a ReloadLua() call
        self:Remove(id)

        -- Find the target item
        local found, parent, i = self:Find(template, selector)
        if not found then
            return nil
        end

        -- Insert or update (depending on offset)
        local prev = nil
        if offset == 0 then
            prev = parent[i]
            item = type(item) == "function" and item(prev) or item
            parent[i] = item
        else
            if offset < 0 then
                offset = offset + 1
            end
            item = type(item) == "function" and item(prev) or item
            table.insert(parent, i+offset, item)
        end

        -- Track the update so it can be removed
        self.tracked[id] = {parent, item, prev}
        return item
    end

    function TemplateHelpers:Remove(id)
        -- Get the tracking data for this item
        local ref = self.tracked[id]
        if not ref then
            return nil
        end
        self.tracked[id] = nil
        local parent, item, prev = table.unpack(ref)

        -- Find the item in the parent and replace it with the prev value (if any) or remove it
        for i, v in ipairs(parent) do
            if v == item then
                if prev then
                    parent[i] = prev
                else
                    table.remove(parent, i)
                end
                return v
            end
        end


        return nil
    end

    function TemplateHelpers:RemoveAll()
        local ids, i = {}, 0

        for id, _ in pairs(self.tracked) do
            i = i + 1
            ids[i] = id
        end

        for _, id in ipairs(ids) do
            self:Remove(id)
        end
    end

end -- if TemplateHelpers.v <= VERSION
