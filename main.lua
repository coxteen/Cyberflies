local WINDOW_WIDTH  = love.graphics.getWidth()
local WINDOW_HEIGHT = love.graphics.getHeight()

local STOP_THRESHOLD           = 60 
local OUT_OF_SCREEN_DIFFERENCE = 60
local BULLET_SPEED             = 600
local ENEMY_SPEED              = 200
local PLAYER_MAX_SPEED         = 300
local PLAYER_ACCELERATION      = 1000
local PLAYER_FRICTION          = 0.98
local MAGIC_ANGLE_DIFFERENCE   = 1.6
local SCALE_FACTOR             = 50

local START_MESSAGE    = "Press left click to start"
local EXIT_MESSAGE     = "Press escape button to exit"
local TUTORIAL_MESSAGE = "Shoot -> Left Click   |   Move -> W + Mouse Movement"

local player = {
    x = WINDOW_WIDTH / 2,
    y = WINDOW_HEIGHT / 2,
    speed = 0,
    angle = 0,
    scale = nil,
    texture = nil
}

local bullets = {}
local enemies = {}

local gameState = "menu"

math.randomseed(os.time())

function love.load()

    enemyDieSound = love.audio.newSource('resources/sounds/enemyDie.wav', "static")
    shootSound = love.audio.newSource('resources/sounds/shoot.wav', "static")
    loseSound = love.audio.newSource('resources/sounds/lose.wav', "static")

    love.graphics.setBackgroundColor(200 / 255, 200 / 255, 200 / 255)

    fontSize = WINDOW_WIDTH / SCALE_FACTOR
    font = love.graphics.newFont("resources/fonts/font.otf", fontSize)

    cursorTexture = love.graphics.newImage('resources/textures/cursor.png')
    love.mouse.setVisible(false)

    backgroundTexture = love.graphics.newImage('resources/textures/background.png')
    player.texture = love.graphics.newImage('resources/textures/player.png')
    local bulletTexture = love.graphics.newImage('resources/textures/bullet.png')
    local enemyTexture  = love.graphics.newImage('resources/textures/enemy.png')

    player.scale = math.min(WINDOW_WIDTH  / player.texture:getWidth() / 10, 
                            WINDOW_HEIGHT / player.texture:getHeight() / 10)

    enemySpawnCooldown = 1
    enemyTimer = 0
    score = 0
    gameState = "menu"

    bulletPrototype = { 
        texture = bulletTexture, 
        speed = BULLET_SPEED, 
        scale = player.scale 
    }
    enemyPrototype = { 
        texture = enemyTexture, 
        speed = ENEMY_SPEED, 
        scale = player.scale 
    }

    music = love.audio.newSource('resources/sounds/music.mp3', "stream")
    music:setLooping(true)
    music:play()
end

function spawnEnemy()
    local side = math.random(4)
    local newX, newY

    if side == 1 then
        newX = math.random(0, WINDOW_WIDTH)
        newY = -OUT_OF_SCREEN_DIFFERENCE
    elseif side == 2 then
        newX = math.random(0, WINDOW_WIDTH)
        newY = WINDOW_HEIGHT + OUT_OF_SCREEN_DIFFERENCE
    elseif side == 3 then
        newX = -OUT_OF_SCREEN_DIFFERENCE
        newY = math.random(0, WINDOW_HEIGHT)
    else
        newX = WINDOW_WIDTH + OUT_OF_SCREEN_DIFFERENCE
        newY = math.random(0, WINDOW_HEIGHT)
    end

    table.insert(enemies, {
        x = newX,
        y = newY,
        speed = enemyPrototype.speed,
        texture = enemyPrototype.texture,
        scale = enemyPrototype.scale
    })
end

function isOutOfScreen(entity)
    return entity.x < -OUT_OF_SCREEN_DIFFERENCE or
           entity.y < -OUT_OF_SCREEN_DIFFERENCE or
           entity.x > WINDOW_WIDTH + OUT_OF_SCREEN_DIFFERENCE or
           entity.y > WINDOW_HEIGHT + OUT_OF_SCREEN_DIFFERENCE
end

function distance(a, b)
    if not a or not b then
        return 0
    end

    local dx = a.x - b.x
    local dy = a.y - b.y

    return math.sqrt(dx * dx + dy * dy)
end

function checkBulletCollision()
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        
        if bullet == nil then
            table.remove(bullets, i)
        else
            if distance(player, bullet) < (player.texture:getWidth() * player.scale) / 2 then
                restartGame()
            end

            for j = #enemies, 1, -1 do
                local enemy = enemies[j]

                if distance(enemy, bullet) < (enemy.texture:getWidth() * enemy.scale) / 2 then
                    table.remove(bullets, i)
                    table.remove(enemies, j)
                    score = score + 1

                    love.audio.play(enemyDieSound)
                    break
                end
            end
        end
    end
end


function restartGame()
    love.audio.play(loseSound)

    gameState = "menu"
    music:setVolume(0.3)

    score = 0

    player.health = 3
    player.x = WINDOW_WIDTH / 2
    player.y = WINDOW_HEIGHT / 2

    for i = #enemies, 1, -1 do
        table.remove(enemies, i)
    end
    for i = #bullets, 1, -1 do
        table.remove(bullets, i)
    end
end

function love.update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    local dx, dy = mouseX - player.x, mouseY - player.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if love.keyboard.isDown("w") and distance > STOP_THRESHOLD then
        dx, dy = dx / distance, dy / distance
        player.speed = math.min(player.speed + PLAYER_ACCELERATION * dt, PLAYER_MAX_SPEED)
        player.x = player.x + dx * player.speed * dt
        player.y = player.y + dy * player.speed * dt
    else
        player.speed = player.speed * PLAYER_FRICTION
    end

    player.x = math.max(0, math.min(player.x, WINDOW_WIDTH))
    player.y = math.max(0, math.min(player.y, WINDOW_HEIGHT))

    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.x = (bullet.x + bullet.speed * math.cos(bullet.angle) * dt) % WINDOW_WIDTH
        bullet.y = (bullet.y + bullet.speed * math.sin(bullet.angle) * dt) % WINDOW_HEIGHT
    end

    enemyTimer = enemyTimer + dt
    if enemyTimer > enemySpawnCooldown then
        enemyTimer = 0
        enemySpawnCooldown = enemySpawnCooldown + 0.05
        for i = 1, score / 10 + 1 do
            spawnEnemy()
        end
    end

    for i = #enemies, 1, -1 do
        local enemy = enemies[i]

        if enemy == nil then
            table.remove(enemies, i)
        else
            local ex, ey = enemy.x, enemy.y
            local dx, dy = player.x - ex, player.y - ey
            local length = math.sqrt(dx * dx + dy * dy)

            if length > player.texture:getWidth() * player.scale / 2 then
                dx, dy = dx / length, dy / length
                enemy.x = enemy.x + dx * enemy.speed * dt
                enemy.y = enemy.y + dy * enemy.speed * dt
            else
                restartGame()
            end

            local enemyAngle = math.atan2(dy, dx)

            local scaleX = enemy.scale
            if enemyAngle > math.pi / 2 or enemyAngle < -math.pi / 2 then
                scaleX = -enemy.scale
            end
            enemy.scaleX = scaleX
        end
    end

    checkBulletCollision()
end

function love.keypressed(key)
    if key == "escape" and gameState == "menu" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and gameState == "menu" then
        gameState = "playing"
        music:setVolume(0.6)
    else
        local dx, dy = x - player.x, y - player.y
        local angle = math.atan2(dy, dx)

        local bulletX = player.x + player.texture:getWidth() * player.scale * math.cos(angle)
        local bulletY = player.y + player.texture:getWidth() * player.scale * math.sin(angle)

        table.insert(bullets, {
            x = bulletX,
            y = bulletY,
            angle = angle,
            speed = bulletPrototype.speed,
            texture = bulletPrototype.texture,
            scale = bulletPrototype.scale
        })

        love.audio.play(shootSound)
    end
end

function love.draw()
    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
    local bgWidth, bgHeight = backgroundTexture:getWidth(), backgroundTexture:getHeight()

    local scaleX = screenWidth / bgWidth
    local scaleY = screenHeight / bgHeight

    love.graphics.draw(backgroundTexture, 0, 0, 0, scaleX, scaleY)

    love.graphics.setFont(font)

    if gameState == "menu" then
        love.graphics.printf(
            START_MESSAGE, 
            0, 
            WINDOW_HEIGHT / 2 - fontSize,
            WINDOW_WIDTH,
            "center"
        )
        love.graphics.printf(
            EXIT_MESSAGE,
            0,
            WINDOW_HEIGHT / 2 + fontSize,
            WINDOW_WIDTH,
            "center"
        )
        love.graphics.printf(
            TUTORIAL_MESSAGE,
            0,
            WINDOW_HEIGHT - 2 * fontSize,
            WINDOW_WIDTH,
            "center"
        )
    elseif gameState == "playing" then
        local mouseX, mouseY = love.mouse.getPosition()
        local dx, dy = mouseX - player.x, mouseY - player.y
        player.angle = math.atan2(dy, dx) + MAGIC_ANGLE_DIFFERENCE

        for _, bullet in ipairs(bullets) do
            love.graphics.draw(
                bullet.texture,
                bullet.x,
                bullet.y,
                bullet.angle,
                bullet.scale,
                bullet.scale,
                bullet.texture:getWidth() / 2,
                bullet.texture:getHeight() / 2
            )
        end

        love.graphics.draw(
            player.texture,
            player.x,
            player.y,
            player.angle,
            player.scale,
            player.scale,
            player.texture:getWidth() / 2,
            player.texture:getHeight() / 2
        )

        for _, enemy in ipairs(enemies) do
            love.graphics.draw(
                enemy.texture,
                enemy.x,
                enemy.y,
                0,
                enemy.scaleX,
                enemy.scale,
                enemy.texture:getWidth() / 2,
                enemy.texture:getHeight() / 2
            )
        end

    love.graphics.print(score, WINDOW_WIDTH / 2 - fontSize / 2, fontSize)
    end

    local x, y = love.mouse.getPosition()
    love.graphics.draw(
        cursorTexture, 
        x, 
        y, 
        0, 
        player.scale, 
        player.scale, 
        cursorTexture:getWidth() / 2, 
        cursorTexture:getHeight() / 2
    )
end