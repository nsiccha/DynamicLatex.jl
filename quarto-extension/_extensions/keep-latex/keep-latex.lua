-- https://pandoc.org/lua-filters.html#module-pandoc
local function starts_with(start, str)
  return str:sub(1, #start) == start
end
return {
  {
      RawInline = function(inline)
          if inline.format == "tex" then
              -- rv = pandoc.read(inline.text).blocks[1].content
              rv = pandoc.utils.blocks_to_inlines(pandoc.read(inline.text).blocks)
              table.insert(rv, pandoc.Space())
              return pandoc.Inlines(rv)
              -- if not starts_with("\\newcommand", inline.text) then
                  -- return pandoc.Inline(inline.text)
              -- end
          else
              quarto.utils.dump(inline.format)
          end
      end
      -- RawBlock = function(block)
      --     -- if block.format == "tex" then
      --     --     quarto.utils.dump(block)
      --     --     if not starts_with("\\newcommand", block.text) then
      --     --         return pandoc.Block(block.text)
      --     --     end
      --     -- else
      --     -- end
      -- end
  }
}