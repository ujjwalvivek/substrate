<script>
    import { onMount } from "svelte";

    const API_BASE = "https://echopoint.ujjwalvivek.com";
    const SOCKET_URL = "wss://echopoint.ujjwalvivek.com/v1/click";

    let button;
    let socket;
    let score = null;
    let status = "";
    let pendingClicks = 0;
    let flushTimer;

    function setRemoteScore(value) {
        const next = Number(value);
        if (Number.isFinite(next)) score = next;
    }

    function flushClicks() {
        if (!pendingClicks) return;
        const count = pendingClicks;
        pendingClicks = 0;

        if (socket?.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify({ type: "click", count }));
            return;
        }

        fetch(`${API_BASE}/v1/click`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ count }),
        }).catch(() => {
            status = "CLICK SERVICE UNAVAILABLE";
        });
    }

    function handleClick() {
        pendingClicks += 1;
        score = (score ?? 0) + 1;
        button?.classList.add("is-pressed");
        setTimeout(() => button?.classList.remove("is-pressed"), 100);

        clearTimeout(flushTimer);
        flushTimer = setTimeout(flushClicks, 300);
    }

    onMount(() => {
        try {
            socket = new WebSocket(SOCKET_URL);
            socket.addEventListener("open", () => {
                status = "LIVE";
            });
            socket.addEventListener("message", (event) => {
                try {
                    const data = JSON.parse(event.data);
                    if (data.global !== undefined) setRemoteScore(data.global);
                } catch {
                    status = "INVALID CLICK SERVICE RESPONSE";
                }
            });
            socket.addEventListener("error", () => {
                status = "HTTP FALLBACK";
            });
            socket.addEventListener("close", () => {
                if (status === "LIVE") status = "HTTP FALLBACK";
            });
        } catch {
            status = "HTTP FALLBACK";
        }

        return () => {
            clearTimeout(flushTimer);
            socket?.close();
        };
    });
</script>

<div class="clicker">
    <button
        bind:this={button}
        class="action-btn clicker-button"
        type="button"
        onclick={handleClick}
    >
        <span class="clicker-score"
            >{score === null ? "..." : score.toLocaleString()}</span
        >
        <span>CLICK ME!</span>
    </button>
    {#if status}
        <small class="clicker-status" aria-live="polite">{status}</small>
    {/if}
</div>
