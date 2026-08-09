const { app, BrowserWindow, Menu, shell } = require("electron");
const path = require("node:path");

const isDevelopment = Boolean(process.env.DESKTOP_DEV_URL);

function createGameWindow() {
  const icon = isDevelopment
    ? path.join(__dirname, "..", "public", "app-icon.png")
    : path.join(__dirname, "..", "dist", "app-icon.png");

  const gameWindow = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1024,
    minHeight: 700,
    backgroundColor: "#201d47",
    title: "WILD DASH 50",
    icon,
    autoHideMenuBar: true,
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  Menu.setApplicationMenu(null);
  gameWindow.once("ready-to-show", () => gameWindow.show());
  gameWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https://")) void shell.openExternal(url);
    return { action: "deny" };
  });
  gameWindow.webContents.on("will-navigate", (event) => event.preventDefault());

  if (isDevelopment) {
    void gameWindow.loadURL(process.env.DESKTOP_DEV_URL);
  } else {
    void gameWindow.loadFile(path.join(__dirname, "..", "dist", "index.html"));
  }
}

app.whenReady().then(() => {
  createGameWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createGameWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
