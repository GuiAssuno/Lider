// Bordas invisíveis para redimensionar a janela sem moldura (usa o gerenciador do SO).
import QtQuick
import Lider

Item {
    id: root
    readonly property int m: 6
    visible: Window.window && Window.window.visibility !== Window.Maximized

    component Edge: MouseArea {
        property int edges: 0
        hoverEnabled: true
        onPressed: if (Window.window) Window.window.startSystemResize(edges)
    }

    Edge { edges: Qt.TopEdge;    height: root.m; anchors { left: parent.left; right: parent.right; top: parent.top } cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.BottomEdge; height: root.m; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.LeftEdge;   width: root.m;  anchors { top: parent.top; bottom: parent.bottom; left: parent.left } cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.RightEdge;  width: root.m;  anchors { top: parent.top; bottom: parent.bottom; right: parent.right } cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.TopEdge | Qt.LeftEdge;     width: 12; height: 12; anchors { top: parent.top; left: parent.left } cursorShape: Qt.SizeFDiagCursor }
    Edge { edges: Qt.TopEdge | Qt.RightEdge;    width: 12; height: 12; anchors { top: parent.top; right: parent.right } cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.BottomEdge | Qt.LeftEdge;  width: 12; height: 12; anchors { bottom: parent.bottom; left: parent.left } cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.BottomEdge | Qt.RightEdge; width: 12; height: 12; anchors { bottom: parent.bottom; right: parent.right } cursorShape: Qt.SizeFDiagCursor }
}
