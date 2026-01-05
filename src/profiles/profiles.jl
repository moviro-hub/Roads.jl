function truck_profile_path()::String
    return joinpath(dirname(@__DIR__), "profiles", "truck-profile", "truck.lua")
end
