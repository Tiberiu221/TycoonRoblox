--!strict
-- Replicile din joc [RIVERKEEP 2]. Deocamdata doar deschiderea.
--
-- Reguli, ca sa nu ajungem iar la un mesaj pe care jucatorul "abia il vede":
--   * Dialogul opreste jocul. Daca personajul poate umbla in timp ce cineva ii vorbeste,
--     replica devine zgomot de fundal si nimeni nu o citeste.
--   * O replica = un gand. Doua propozitii scurte, nu un paragraf.
--   * Ultima replica spune ce are de facut jucatorul. Ea ramane in minte, nu prima.
-- Textele sunt in engleza (jocul e in engleza), comentariile in romana.
export type Line = { text: string }
export type Scene = { id: string, lines: { Line } }

local DialogueConfig = {}

-- Cate semne pe secunda apar la scriere. Sub 30 devine enervant, peste 70 nu se mai citeste
-- ca vorbire.
DialogueConfig.CHARS_PER_SECOND = 46

DialogueConfig.SCENES = {
    intro = {
        id = "intro",
        -- Cele patru replici raspund la cele patru intrebari pe care le are oricine intra
        -- prima data, in ordinea in care si le pune. Varianta veche era atmosferica si nu
        -- raspundea la NICIUNA: dupa ea nu stiai unde esti, ce e locul asta sau ce esti tu.
        lines = {
            -- 1. unde sunt si cine sunt eu
            {
                text = "You're the one keeping this place, then. Riverkeep, they call it — what's left of it.",
            },
            -- 2. ce e motorul lumii
            {
                text = "I came down on the current with a coat and a bad knee. The river brings everything here eventually.",
            },
            -- 3. ce fac eu, jucatorul: DECID. Asta e verbul jocului.
            {
                text = "Broken things, mostly. Sometimes people. What this settlement becomes is your call, not mine.",
            },
            -- 4. ce fac ACUM. Ultima replica ramane in minte, deci ea duce primul pas.
            {
                text = "Start with a net in the water. I'll earn my bed sorting whatever it drags up.",
            },
        },
    },
} :: { [string]: Scene }

function DialogueConfig.get(id: string): Scene?
    return DialogueConfig.SCENES[id]
end

return DialogueConfig
