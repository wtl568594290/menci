--open door:5,close door:6,remove lock:7,lock lock:1,quantity low:2,led:4
pinActionStart_G, pinActionStop_G = 5, 6
pinLockRemove_G, pinLockLock_G = 7, 1
pinQuantityLow_G = 2
pinTable = {pinActionStart_G, pinActionStop_G, pinLockRemove_G, pinLockLock_G, pinQuantityLow_G}
for i = 1, #pinTable do
    gpio.write(pinTable[i], gpio.LOW)
    gpio.mode(pinTable[i], gpio.INT)
    gpio.mode(pinTable[i], gpio.INPUT)
end

pinLed_G = 4
gpio.mode(pinLed_G, gpio.OUTPUT)
gpio.write(pinLed_G, gpio.LOW)

--insert url
baseUrl_G = "http://www.alzhihuiyanglao.com/gateMagnetController.do?gateRecord"
deviceCode_G = string.upper(string.gsub(wifi.sta.getmac(), ":", ""))
action_G, actionStart_G, actionStop_G = "042", "043", "042"
lock_G, lockRemove_G, lockLock_G = 0, 1, 0
quantityHigh_G, quantityLow_G = 100, 0
function insertURL(quantity)
    if not isConfigRun_G then
        local url =
            string.format(
            "%s&deviceCode=%s&actionType=%s&lock=%s&quantity=%s",
            baseUrl_G,
            deviceCode_G,
            action_G,
            lock_G,
            quantity
        )
        table.insert(urlList_G, url)
    end
end
--wifi init
wifi.setmode(wifi.STATION)
wifi.sta.autoconnect(1)
wifi.sta.sleeptype(wifi.MODEM_SLEEP)

wifi.eventmon.register(
    wifi.eventmon.STA_GOT_IP,
    function(T)
        print("wifi is connected,ip is " .. T.IP)
        gpio.write(pinLed_G, gpio.HIGH)
    end
)

wifi.eventmon.register(
    wifi.eventmon.STA_DISCONNECTED,
    function(T)
        print("STA - DISCONNECTED")
        gpio.write(pinLed_G, gpio.LOW)
    end
)

--config net
function configNet()
    isConfigRun_G = true
    print("start config net")
    wifi.startsmart(
        0,
        function()
            isConfigRun_G = nil
            insertURL(quantityHigh_G)
        end
    )
    tmr.create():alarm(
        1000 * 90,
        tmr.ALARM_SINGLE,
        function()
            if isConfigRun_G then
                isConfigRun_G = nil
                wifi.stopsmart()
            end
        end
    )
end

--boot
bootCount_G = 0
function boot()
    local ssid = wifi.sta.getconfig()
    if ssid == nil or ssid == "" then
        configNet()
    else
        tmr.create():alarm(
            100,
            tmr.ALARM_AUTO,
            function(timer)
                if wifi.sta.status() ~= wifi.STA_GOTIP then
                    bootCount_G = bootCount_G + 1
                    if bootCount_G > 100 then
                        timer:unregister()
                        bootCount_G = 0
                        configNet()
                    end
                else
                    timer:unregister()
                    bootCount_G = 0
                end
            end
        )
    end
end
boot()

-----------------
-- get request
urlList_G = {}
ready_G = true
tryCount_G = 0
wakeCount_G = 0
tmr.create():alarm(
    1000,
    tmr.ALARM_AUTO,
    function()
        if #urlList_G > 0 then
            wakeCount_G = 0
            if ready_G then
                tryCount_G = tryCount_G + 1
                if tryCount_G <= 5 then
                    if wifi.sta.status() == wifi.STA_GOTIP then
                        ready_G = false
                        print(urlList_G[1])
                        http.get(
                            urlList_G[1],
                            nil,
                            function(code)
                                print(code)
                                if code > 0 then
                                    table.remove(urlList_G, 1)
                                    tryCount_G = 0
                                end
                                ready_G = true
                            end
                        )
                    end
                else
                    urlList_G = {}
                    tryCount_G = 0
                end
            end
        else
            wakeCount_G = wakeCount_G + 1
            if wakeCount_G == 60 * 60 * 24 then
                insertURL(quantityHigh_G)
            end
        end
    end
)

for i = 1, #pinTable do
    local function cb()
        gpio.trig(pinTable[i])
        print(pinTable[i] .. "is up")
        if pinTable[i] == pinActionStart_G then
            print("open door")
            action_G = actionStart_G
            insertURL(quantityHigh_G)
        elseif pinTable[i] == pinActionStop_G then
            print("close door")
            action_G = actionStop_G
            insertURL(quantityHigh_G)
        elseif pinTable[i] == pinLockRemove_G then
            print("remove lock")
            lock_G = lockRemove_G
        elseif pinTable[i] == pinLockLock_G then
            print("lock lock")
            lock_G = lockLock_G
        else
            insertURL(quantityLow_G)
            print("quantity low")
        end
        tmr:create():alarm(
            1000,
            tmr.ALARM_SINGLE,
            function()
                gpio.trig(pinTable[i], "up", cb)
            end
        )
    end
    gpio.trig(pinTable[i], "up", cb)
end

--welcome
VERSION = 1.01
print("menci version = " .. VERSION)
