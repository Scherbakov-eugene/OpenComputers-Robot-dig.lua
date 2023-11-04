local component = require("component")
local computer = require("computer")
local keys = require("keyboard").keys
local event = require("event")
local term = require("term")
local gpu = component.gpu
local shell = require("shell")
local sides = require("sides")
local robot

local facing = {
  front = 0,
  right = 1,
  back = 2,
  left = 3,
}

local x, y, z = 0, 0, 0
local f = facing.front

local args, options = shell.parse(...)

-- Повернуть робота в нужную сторону
-- за меньшее число поворотов.
local function turnTo(facingTo)
  local df = facingTo - f

  if df == 3 then
    df = -1
  elseif df == -3 then
    df = 1
  end

    while (df > 0) do
      if (robot.turnRight()) then
        f = f + 1
        df = df - 1
      else
        print("Error: can't turn robot right.")
        os.exit(0)
      end
    end

    while (df < 0) do
      if (robot.turnLeft()) then
        f = f - 1
        df = df + 1
      else
        print("Error: can't turn robot left.")
        os.exit(0)
      end
    end

  while (f < 0) do
    f = f + 4
  end

  while (f > 3) do
    f = f - 4
  end
end

local function printUsage()
  print("Usage:")
  print("  dig Xmin Xmax Ymin Ymax Zmin Zmax")
  print("Example (area w=50, h=8, d=50):")
  print("  dig 0 49 0 7 0 49")
  print("Example (tunnel w=4, h=4, d=100):")
  print("  dig 0 3 0 3 0 99")
  print("Coordinate system (top view):")
  print("            Zmax")
  print("             ^")
  print("             |")
  print("  Xmin <-- Robot --> Xmax")
  print("             |")
  print("             V")
  print("            Zmin")
  print("Robot stay before digging area in position (0, 0, 0).")
  print("Robot start digging from upper layer.")
  print("")
end

-- Проверить наличие кирки
-- (инструмента для копания блоков).
function checkTool()
end

-- Пытается переместить робота на один блок.
-- При необходимости копает блок.
function digBlock(dx, dy, dz)
  -- what may be: entity, solid, replaceable,
  -- liquid, passable, air.
  local result, what    -- robot.detect()
  local success, reason -- robot.swing()

  local delta = math.abs(dx) + math.abs(dy) + math.abs(dz)
  if (delta > 1) then
    print("Error: delta greater than 1.")
    os.exit(0)
  end

  -- Поворачиваем робота в нужную сторону.
  if (dx == -1) then
    turnTo(facing.left)
  elseif (dx == 1) then
    turnTo(facing.right)
  elseif (dz == -1) then
    turnTo(facing.back)
  elseif (dz == 1) then
    turnTo(facing.front)
  end

  -- Если перемещение по Y.
  if (dy ~= 0) then
    if (dy == 1) then
      local r = true
      while (r) do
        r = false

        result, what = robot.detectUp()
        if (what == "solid" or
            what == "passable") then
          checkTool()
          success, reason = robot.swingUp()

          robot.suck()

          if (not success) then
            r = true
            os.sleep(1)
            goto continue1
          end
        end

        success = robot.up()

        if (not success) then
          r = true
          os.sleep(1)
          --print("Error: can't move up.")
          --os.exit(0)
        else
          y = y + 1
        end
        ::continue1::
      end
    elseif (dy == -1) then
      local r = true
      while (r) do
        r = false

        result, what = robot.detectDown()
        if (what == "solid" or
            what == "passable") then
          checkTool()
          success, reason = robot.swingDown()

          robot.suck()

          if (not success) then
            r = true
            os.sleep(1)
            goto continue2
          end
        end

        success = robot.down()

        if (not success) then
          r = true
          os.sleep(1)
          --print("Error: can't move down.")
          --os.exit(0)
        else
          y = y - 1
        end
        ::continue2::
      end
    end
  -- Перемещение по XZ.
  else
      local r = true
      while (r) do
        r = false

        result, what = robot.detect()
        if (what == "solid" or
            what == "passable") then
          checkTool()
          success, reason = robot.swing()

          robot.suck()

          if (not success) then
            r = true
            os.sleep(1)
            goto continue3
          end
        end

        success = robot.forward()

        if (not success) then
          r = true
          os.sleep(1)
          --print("Error: can't move.")
          --os.exit(0)
        else
          if (f == facing.front) then
            z = z + 1
          elseif (f == facing.right) then
            x = x + 1
          elseif (f == facing.back) then
            z = z - 1
          elseif (f == facing.left) then
            x = x - 1
          end
        end
        ::continue3::
      end
  end
end

-- Переместиться в указанную позицию.
-- При необходимости копать блоки на маршруте.
function digTo(toX, toY, toZ)
  while (x ~= toX or y ~= toY or z ~= toZ) do
    -- Выравниваем Y.
    if (toY > y) then
      digBlock(0, 1, 0)
    elseif (toY < y) then
      digBlock(0, -1, 0)
    end

    -- Выравниваем Z.
    if (toZ > z) then
      digBlock(0, 0, 1)
    elseif (toZ < z) then
      digBlock(0, 0, -1)
    end

    -- Выравниваем X.
    if (toX > x) then
      digBlock(1, 0, 0)
    elseif (toX < x) then
      digBlock(-1, 0, 0)
    end
  end
end

function main()
  if #args == 0 then
    printUsage()
    os.exit(1)
  end

  if (not component.isAvailable("robot")) then
    print("This program must be run on a robot!")
    os.exit(1)
  end

  robot = require("robot")

--[[  print("args:")
  for a, b in pairs(args) do
    print(tostring(a) .. " = " .. tostring(b))
  end
  print()

  print("options:")
  for a, b in pairs(options) do
    print(tostring(a) .. " = " .. tostring(b))
  end
  print()]]

  local xmin = tonumber(args[1])
  local xmax = tonumber(args[2])
  local ymin = tonumber(args[3])
  local ymax = tonumber(args[4])
  local zmin = tonumber(args[5])
  local zmax = tonumber(args[6])

  print("Parameters:")
  print("xmin = " .. xmin .. ", xmax = " .. xmax)
  print("ymin = " .. ymin .. ", ymax = " .. ymax)
  print("zmin = " .. zmin .. ", zmax = " .. zmax)

  local xlen = xmax - xmin + 1
  local ylen = ymax - ymin + 1
  local zlen = zmax - zmin + 1
  local total = xlen * ylen * zlen
  local stacks = total / 64
  print("Total blocks = " .. xlen .. " * " .. ylen .. " * " .. zlen .. " = " .. total .. " = " .. stacks .. " * " .. 64)

  -- Левый нижний угол верхнего слоя.
  digTo(xmin, ymax, zmin)

  -- Срезаем блоки по слоям с верхнего.
  local layerIMax = ymax - ymin
  for layerI = 0, layerIMax do
    local layer = ymax - layerI

    local rowInverted = false
    if (z == zmax) then
      rowInverted = true
    end
    local rowIMax = zmax - zmin
    local row
    for rowI = 0, rowIMax do
      if (rowInverted) then
        row = zmax - rowI
      else
        row = zmin + rowI
      end

      if (x == xmin) then
        digTo(xmin, layer, row)
        digTo(xmax, layer, row)
      else
        digTo(xmax, layer, row)
        digTo(xmin, layer, row)
      end
    end
  end

  -- Бурение завершено.
  print("Digging finished.")
  computer.shutdown()
end

main()