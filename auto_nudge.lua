-- auto_nudge.lua
-- SCRIPT_NAME: AutoNudge
-- SCRIPT_DESC: Adds pilot throttle nudge (Z-axis) in AUTO mode
-- SCRIPT_VEHICLE: Copter

local SCRIPT_NAME = "AutoNudge"

-- --- Parameters ---
local MAX_NUDGE_SPEED_MS = 1.0  -- Max 1.0 m/s vertical nudge (adjust as needed)
local THROTTLE_CHAN = 3         -- RC Channel 3 for Throttle
local AUTO_MODE_NUM = 3         -- Flight mode number for AUTO
-- --------------------

-- This update function will be called repeatedly
local function update()
    
    -- Only run in AUTO mode
    if vehicle:get_mode() ~= AUTO_MODE_NUM then
        -- We must clear the offset when not in AUTO mode
        poscontrol:set_posvelaccel_offset(nil, Vector3f(0,0,0), nil)
        return update, 100 -- Run again in 100ms
    end

    -- Get throttle RC input
    local throttle_in = rc:get_channel(THROTTLE_CHAN)
    
    -- Check if channel is valid
    if not throttle_in or not throttle_in:get_control_mid() then
        gcs:send_text(gcs.WARNING, SCRIPT_NAME .. ": Throttle chan not found")
        return update, 1000 -- Check again in 1 second
    end

    -- Get normalized throttle input (-1.0 to 1.0)
    local throttle_mid = throttle_in:get_control_mid()
    local throttle_norm = (throttle_in:get_pwm() - throttle_mid) / (throttle_mid - 1000) -- Assumes 1000-1500-2000 range
    throttle_norm = math.min(math.max(throttle_norm, -1.0), 1.0) -- Constrain

    -- Calculate vertical nudge speed (m/s)
    -- In NED frame, negative Z is UP.
    -- Pilot throttle UP (positive norm) should command UP (negative Z).
    local nudge_z_ms = -throttle_norm * MAX_NUDGE_SPEED_MS

    -- Create the velocity offset vector (NED, m/s)
    local vel_offset_ms = Vector3f(0, 0, nudge_z_ms)

    -- Set the offset
    -- We pass 'nil' for position and acceleration offsets as we only want to offset velocity
    local success = poscontrol:set_posvelaccel_offset(nil, vel_offset_ms, nil)

    if not success then
        gcs:send_text(gcs.WARNING, SCRIPT_NAME .. ": Failed to set offset")
    end

    return update, 100 -- Run this function again in 100ms (10Hz)
end

-- Initial run
return update, 100