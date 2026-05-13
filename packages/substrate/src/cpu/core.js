export function createStore(initialState = {}) {
    return new Proxy(initialState, {
        set(target, prop, value) {
            target[prop] = value;
            window.dispatchEvent(
                new CustomEvent("state:update", {
                    detail: { prop, value },
                }),
            );
            return true;
        },
    });
}

export function createRouter(routes, targetElementId = "app") {
    const target = document.getElementById(targetElementId);
    const render = () => {
        const path = window.location.hash.slice(1) || "/";
        const view = routes[path] || routes["/404"] || "<h1>404</h1>";
        target.innerHTML = typeof view === "function" ? view() : view;
    };
    window.addEventListener("hashchange", render);
    document.body.addEventListener("click", (e) => {
        if (e.target.matches("[data-link]")) {
            e.preventDefault();
            const href = e.target.getAttribute("href");
            if (window.location.hash !== href) {
                window.location.hash = href;
            } else {
                render();
            }
        }
    });
    render();
}
