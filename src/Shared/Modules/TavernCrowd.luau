--!strict
-- Cati clienti stau la taverna [D50]: cati vin = cat vinzi, CHIAR ACUM. Nu `dock.rate` -- aia e cat
-- POATE vinde taverna: un Innkeeper nou ar fi umplut-o de clienti si fara nicio scandura, iar desenul
-- ar fi mintit [D40]. Fereastra se stinge: fiecare vanzare (Sold, cu bucatile ei) intra cu ora ei, iar
-- ce e mai vechi de WINDOW secunde iese. Pur: `now` vine ca parametru.
local TavernCrowd = {}

TavernCrowd.WINDOW = 20
TavernCrowd.MAX = 8

export type Sale = { at: number, items: number }
export type Window = { sales: { Sale } }

function TavernCrowd.new(): Window
    return { sales = {} }
end

-- vanzarile vin in ordinea timpului, deci ce a expirat sta mereu la inceput
local function forget(w: Window, now: number)
    while #w.sales > 0 and now - w.sales[1].at >= TavernCrowd.WINDOW do
        table.remove(w.sales, 1)
    end
end

function TavernCrowd.add(w: Window, now: number, items: number)
    if not math.isfinite(items) or items <= 0 then
        return
    end
    table.insert(w.sales, { at = now, items = items })
    forget(w, now)
end

-- Bucati vandute pe secunda, in ultimele WINDOW secunde.
function TavernCrowd.rate(w: Window, now: number): number
    forget(w, now)
    local total = 0
    for _, s in w.sales do
        total += s.items
    end
    return total / TavernCrowd.WINDOW
end

-- Un client asteapta si cand nu se vinde nimic: taverna nu e pustie, doar linistita. Apoi unul in plus
-- pentru fiecare bucata pe secunda, pana la MAX.
function TavernCrowd.count(w: Window, now: number): number
    return math.clamp(1 + math.floor(TavernCrowd.rate(w, now)), 1, TavernCrowd.MAX)
end

return TavernCrowd
