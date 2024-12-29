local data = require('data.min')
local battery = require('battery.min')
local code = require('code.min')
local image_sprite_block = require('image_sprite_block.min')

-- Phone to Frame flags
IMAGE_SPRITE_BLOCK = 0x20
CLEAR_MSG = 0x10

-- register the message parsers so they are automatically called when matching data comes in
data.parsers[IMAGE_SPRITE_BLOCK] = image_sprite_block.parse_image_sprite_block
data.parsers[CLEAR_MSG] = code.parse_code

-- Main app loop
function app_loop()
	-- clear the display
	frame.display.text(" ", 1, 1)
	frame.display.show()
    local last_batt_update = 0

	while true do
		-- process any raw data items, if ready
		local items_ready = data.process_raw_items()

		-- one or more full messages received
		if items_ready > 0 then

			if (data.app_data[IMAGE_SPRITE_BLOCK] ~= nil) then
				-- show the image sprite block
				local isb = data.app_data[IMAGE_SPRITE_BLOCK]

				-- it can be that we haven't got any sprites yet, so only proceed if we have a sprite
				if isb.current_sprite_index > 0 then
					-- either we have all the sprites, or we want to do progressive/incremental rendering
					if isb.progressive_render or (isb.active_sprites == isb.total_sprites) then

						for index = 1, isb.active_sprites do
							local spr = isb.sprites[index]
							local y_offset = isb.sprite_line_height * (index - 1)

							-- set the palette the first time, all the sprites should have the same palette
							if index == 1 then
								image_sprite_block.set_palette(spr.num_colors, spr.palette_data)
							end

							frame.display.bitmap(1, y_offset + 1, spr.width, 2^spr.bpp, 0, spr.pixel_data)
						end

						frame.display.show()
					end
				end
			end

			if (data.app_data[CLEAR_MSG] ~= nil) then
				-- clear the display
				frame.display.text(" ", 1, 1)
				frame.display.show()

				data.app_data[CLEAR_MSG] = nil
			end
		end

        -- periodic battery level updates, 120s for a camera app
        last_batt_update = battery.send_batt_if_elapsed(last_batt_update, 120)
		frame.sleep(0.005)
	end
end

-- run the main app loop
app_loop()