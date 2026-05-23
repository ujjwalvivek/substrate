<script>
    import { onMount, tick } from "svelte";

    export let value = "";
    export let options = [];
    export let ariaLabel = "";
    export let onValueChange = () => {};

    let container;
    let trigger;
    let menu;
    let open = false;
    let highlighted = 0;

    function portal(node) {
        document.body.appendChild(node);
        return { destroy() {} };
    }

    $: selectedIndex = Math.max(
        options.findIndex((option) => String(option.value) === String(value)),
        0,
    );
    $: selectedOption = options[selectedIndex];
    $: if (!open) highlighted = selectedIndex;

    function openMenu() {
        if (!options.length) return;
        open = true;
        highlighted = selectedIndex;
        tick().then(() => menu?.focus());
    }

    function closeMenu(restoreFocus = true) {
        open = false;
        if (restoreFocus) tick().then(() => trigger?.focus());
    }

    function positionMenu() {
        if (!menu || !trigger) return;
        const rect = trigger.getBoundingClientRect();
        const viewportPadding = 8;
        const maxHeight = Math.min(280, window.innerHeight * 0.42);
        const estimatedHeight = Math.min(maxHeight, options.length * 30 + 6);
        const roomBelow = window.innerHeight - rect.bottom - viewportPadding;
        const openUp = roomBelow < estimatedHeight && rect.top > roomBelow;
        const left = Math.min(
            Math.max(viewportPadding, rect.left),
            Math.max(
                viewportPadding,
                window.innerWidth - rect.width - viewportPadding,
            ),
        );

        menu.style.left = `${left}px`;
        menu.style.width = `${rect.width}px`;
        menu.style.maxHeight = `${Math.max(80, openUp ? rect.top - viewportPadding * 2 : roomBelow)}px`;
        if (openUp) {
            menu.style.top = "auto";
            menu.style.bottom = `${window.innerHeight - rect.top + 4}px`;
        } else {
            menu.style.bottom = "auto";
            menu.style.top = `${rect.bottom + 4}px`;
        }
    }

    function toggleMenu() {
        if (open) closeMenu();
        else openMenu();
    }

    function choose(option) {
        value = option.value;
        onValueChange(option.value);
        closeMenu();
    }

    function handleTriggerKeydown(event) {
        if (["Enter", " ", "ArrowDown", "ArrowUp"].includes(event.key)) {
            event.preventDefault();
            openMenu();
        }
    }

    function handleMenuKeydown(event) {
        if (event.key === "ArrowDown") {
            event.preventDefault();
            highlighted = (highlighted + 1) % options.length;
        } else if (event.key === "ArrowUp") {
            event.preventDefault();
            highlighted = (highlighted - 1 + options.length) % options.length;
        } else if (event.key === "Home") {
            event.preventDefault();
            highlighted = 0;
        } else if (event.key === "End") {
            event.preventDefault();
            highlighted = options.length - 1;
        } else if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            if (options[highlighted]) choose(options[highlighted]);
        } else if (event.key === "Escape") {
            event.preventDefault();
            closeMenu();
        }
    }

    function swatchStyle(option) {
        const colors = option?.swatch;
        if (!Array.isArray(colors) || colors.length < 3) return "";
        return `--swatch-primary:${colors[0]};--swatch-secondary:${colors[1]};--swatch-accent:${colors[2]};`;
    }

    onMount(() => {
        const handleOutsidePointer = (event) => {
            const target = event.target;
            if (!container?.contains(target) && !menu?.contains(target))
                open = false;
        };

        document.addEventListener("pointerdown", handleOutsidePointer);
        const reposition = () => positionMenu();
        window.addEventListener("resize", reposition);
        window.addEventListener("scroll", reposition, true);
        return () => {
            document.removeEventListener("pointerdown", handleOutsidePointer);
            window.removeEventListener("resize", reposition);
            window.removeEventListener("scroll", reposition, true);
        };
    });

    $: if (open) tick().then(positionMenu);
</script>

<div class="dropdown" class:is-open={open} bind:this={container}>
    <button
        bind:this={trigger}
        type="button"
        class="ui-select dropdown-trigger"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={ariaLabel}
        onclick={toggleMenu}
        onkeydown={handleTriggerKeydown}
    >
        <span class="dropdown-value">
            {#if selectedOption?.swatch?.length}
                <span
                    class="dropdown-swatch"
                    style={swatchStyle(selectedOption)}
                    aria-hidden="true"
                ></span>
            {/if}
            <span>{selectedOption?.label ?? ""}</span>
        </span>
    </button>

    {#if open}
        <div
            bind:this={menu}
            use:portal
            class="dropdown-menu"
            role="listbox"
            tabindex="0"
            aria-label={ariaLabel}
            onkeydown={handleMenuKeydown}
        >
            {#each options as option, index (String(option.value))}
                <button
                    type="button"
                    class="dropdown-option"
                    class:is-highlighted={index === highlighted}
                    role="option"
                    aria-selected={String(option.value) === String(value)}
                    onclick={() => choose(option)}
                    onmouseenter={() => (highlighted = index)}
                >
                    <span class="dropdown-option-content">
                        {#if option.swatch?.length}
                            <span
                                class="dropdown-swatch"
                                style={swatchStyle(option)}
                                aria-hidden="true"
                            ></span>
                        {/if}
                        <span>{option.label}</span>
                    </span>
                </button>
            {/each}
        </div>
    {/if}
</div>
