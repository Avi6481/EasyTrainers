local Rotation = {}

function Rotation.FromAxisAngle(axis, degrees)
    local half = math.rad(degrees) * 0.5
    local s = math.sin(half)
    return { i = axis.x * s, j = axis.y * s, k = axis.z * s, r = math.cos(half) }
end

function Rotation.FromYaw(degrees)
    return Rotation.FromAxisAngle({ x = 0, y = 0, z = 1 }, degrees)
end

function Rotation.FromQuaternion(quaternion)
    return { i = quaternion.i, j = quaternion.j, k = quaternion.k, r = quaternion.r }
end

function Rotation.Multiply(a, b)
    return {
        i = a.r * b.i + a.i * b.r + a.j * b.k - a.k * b.j,
        j = a.r * b.j - a.i * b.k + a.j * b.r + a.k * b.i,
        k = a.r * b.k + a.i * b.j - a.j * b.i + a.k * b.r,
        r = a.r * b.r - a.i * b.i - a.j * b.j - a.k * b.k
    }
end

function Rotation.Normalize(q)
    local length = math.sqrt(q.i * q.i + q.j * q.j + q.k * q.k + q.r * q.r)
    if length < 1e-8 then return { i = 0, j = 0, k = 0, r = 1 } end
    return { i = q.i / length, j = q.j / length, k = q.k / length, r = q.r / length }
end

function Rotation.Conjugate(q)
    return { i = -q.i, j = -q.j, k = -q.k, r = q.r }
end

function Rotation.Rotate(q, v)
    local tx = 2 * (q.j * v.z - q.k * v.y)
    local ty = 2 * (q.k * v.x - q.i * v.z)
    local tz = 2 * (q.i * v.y - q.j * v.x)
    return {
        x = v.x + q.r * tx + (q.j * tz - q.k * ty),
        y = v.y + q.r * ty + (q.k * tx - q.i * tz),
        z = v.z + q.r * tz + (q.i * ty - q.j * tx)
    }
end

function Rotation.ToQuaternion(q)
    return Quaternion.new(q.i, q.j, q.k, q.r)
end

return Rotation
