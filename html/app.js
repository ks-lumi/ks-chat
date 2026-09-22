(() => {
    'use strict';

    const root = document.getElementById('ks-chat');
    const messagesEl = document.getElementById('ks-chat-messages');
    const suggestionsEl = document.getElementById('ks-chat-suggestions');
    const inputEl = document.getElementById('ks-chat-input');

    const resourceName = (window.GetParentResourceName && window.GetParentResourceName()) || 'ks-chat';

    let state = {
        maxMessages: 100,
        maxLength: 200,
        autoHideDelay: 12000,
        playSound: true,
        focused: false,
        suggestions: [],
        activeSuggestionIndex: -1,
        history: [],
        historyIndex: -1,
    };

    let hideTimer = null;

    function post(endpoint, data) {
        return fetch(`https://${resourceName}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function scheduleAutoHide() {
        if (hideTimer) clearTimeout(hideTimer);
        if (state.autoHideDelay <= 0) return;
        root.classList.remove('hidden');
        hideTimer = setTimeout(() => {
            if (!state.focused) root.classList.add('hidden');
        }, state.autoHideDelay);
    }

    function playPingSound() {
        if (!state.playSound) return;
        try {
            const ctx = new (window.AudioContext || window.webkitAudioContext)();
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.value = 740;
            gain.gain.setValueAtTime(0.05, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.25);
            osc.connect(gain).connect(ctx.destination);
            osc.start();
            osc.stop(ctx.currentTime + 0.25);
        } catch (e) { /* ignore */ }
    }

    function renderFallback(message) {
        // Compatibilité avec le format par défaut du chat FiveM/RedM : {args, color, multiline}
        const [a1, a2] = message.args || [];
        const color = message.color ? `rgb(${message.color[0]},${message.color[1]},${message.color[2]})` : null;
        const wrapper = document.createElement('div');
        wrapper.className = 'ks-msg ks-msg--say';
        if (a2 !== undefined) {
            wrapper.innerHTML = `<span class="ks-name"${color ? ` style="color:${color}"` : ''}>${a1}</span><span class="ks-text">${a2}</span>`;
        } else {
            wrapper.innerHTML = `<span class="ks-text"${color ? ` style="color:${color}"` : ''}>${a1 || ''}</span>`;
        }
        return wrapper;
    }

    function addMessage(message) {
        const holder = document.createElement('div');

        if (message.template) {
            holder.innerHTML = message.template;
        } else if (message.args) {
            holder.appendChild(renderFallback(message));
            messagesEl.appendChild(holder.firstChild);
            trimAndScroll();
            return;
        } else {
            return;
        }

        while (holder.firstChild) {
            messagesEl.appendChild(holder.firstChild);
        }

        trimAndScroll();
        playPingSound();
        scheduleAutoHide();
    }

    function trimAndScroll() {
        while (messagesEl.children.length > state.maxMessages) {
            messagesEl.removeChild(messagesEl.firstChild);
        }
        messagesEl.scrollTop = messagesEl.scrollHeight;
    }

    function clearMessages() {
        messagesEl.innerHTML = '';
    }

    // -------------------------------------------------------
    // Suggestions
    // -------------------------------------------------------

    function updateSuggestions() {
        const raw = inputEl.value;
        state.activeSuggestionIndex = -1;

        if (!raw.startsWith('/') || raw.includes(' ')) {
            suggestionsEl.classList.remove('visible');
            suggestionsEl.innerHTML = '';
            return;
        }

        const term = raw.slice(1).toLowerCase();
        const matches = state.suggestions
            .filter((s) => s.name.toLowerCase().startsWith(term))
            .slice(0, 8);

        if (matches.length === 0) {
            suggestionsEl.classList.remove('visible');
            suggestionsEl.innerHTML = '';
            return;
        }

        suggestionsEl.innerHTML = matches.map((s, i) => {
            const params = (s.params || []).map((p) => `[${p.name}]`).join(' ');
            return `<div class="ks-suggestion" data-index="${i}">
                <span class="ks-suggestion-cmd">/${s.name}</span>
                <span class="ks-suggestion-params">${params}</span>
                <span class="ks-suggestion-help">${s.help || ''}</span>
            </div>`;
        }).join('');

        suggestionsEl.classList.add('visible');
    }

    // -------------------------------------------------------
    // Focus / saisie
    // -------------------------------------------------------

    function focusChat() {
        state.focused = true;
        root.classList.add('focused');
        root.classList.remove('hidden');
        inputEl.value = '';
        state.historyIndex = -1;
        setTimeout(() => inputEl.focus(), 30);
        if (hideTimer) clearTimeout(hideTimer);
    }

    function blurChat() {
        state.focused = false;
        root.classList.remove('focused');
        suggestionsEl.classList.remove('visible');
        inputEl.blur();
        // Fermeture explicite du chat (Echap / envoi du message / focus
        // retiré côté client) : le fil de messages disparaît tout de
        // suite (pas de fondu), sans attendre le délai d'auto-hide
        // habituel (celui-ci reste utilisé pour faire disparaître les
        // messages après une période d'inactivité quand le chat n'a
        // jamais été ouvert).
        if (hideTimer) clearTimeout(hideTimer);
        messagesEl.style.transition = 'none';
        root.classList.add('hidden');
        requestAnimationFrame(() => {
            requestAnimationFrame(() => { messagesEl.style.transition = ''; });
        });
    }

    function submit() {
        const text = inputEl.value;
        if (text.trim() !== '') {
            state.history.push(text);
        }
        post('ks-chat:submit', { message: text });
        blurChat();
    }

    function cancel() {
        post('ks-chat:close');
        blurChat();
    }

    inputEl.addEventListener('input', updateSuggestions);

    inputEl.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            submit();
        } else if (e.key === 'Escape') {
            e.preventDefault();
            cancel();
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (state.history.length === 0) return;
            if (state.historyIndex === -1) state.historyIndex = state.history.length - 1;
            else if (state.historyIndex > 0) state.historyIndex--;
            inputEl.value = state.history[state.historyIndex] || '';
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (state.historyIndex === -1) return;
            if (state.historyIndex < state.history.length - 1) {
                state.historyIndex++;
                inputEl.value = state.history[state.historyIndex] || '';
            } else {
                state.historyIndex = -1;
                inputEl.value = '';
            }
        } else if (e.key === 'Tab') {
            e.preventDefault();
            const first = suggestionsEl.querySelector('.ks-suggestion');
            if (first) {
                const cmd = first.querySelector('.ks-suggestion-cmd').textContent;
                inputEl.value = cmd + ' ';
                updateSuggestions();
            }
        }
    });

    // -------------------------------------------------------
    // Messages NUI
    // -------------------------------------------------------

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.type) return;

        switch (data.type) {
            case 'ks-chat:init':
                // Configuration uniquement : ne doit PAS rendre le panneau
                // visible tout seul (scheduleAutoHide() le faisait, ce qui
                // affichait un cadre vide quelques secondes après le
                // démarrage de la ressource, avant même la sélection du
                // personnage). La visibilité ne doit être déclenchée que
                // par un vrai message (addMessage) ou l'ouverture du chat
                // (focusChat).
                state.maxMessages = data.maxMessages ?? state.maxMessages;
                state.maxLength = data.maxLength ?? state.maxLength;
                state.autoHideDelay = data.autoHideDelay ?? state.autoHideDelay;
                state.playSound = data.playSound ?? state.playSound;
                inputEl.maxLength = state.maxLength;
                break;

            case 'ks-chat:focus':
                if (data.focus) focusChat(); else blurChat();
                break;

            case 'ks-chat:message':
                addMessage(data.message);
                break;

            case 'ks-chat:clear':
                clearMessages();
                break;

            case 'ks-chat:suggestions':
                state.suggestions = data.suggestions || [];
                break;
        }
    });

    document.addEventListener('click', () => {
        // Empêche les clics de fermer accidentellement la saisie via propagation NUI
    });
})();
