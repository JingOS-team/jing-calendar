/*
 *   Copyright 2018 Dimitris Kardarakos <dimkard@gmail.com>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License as
 *   published by the Free Software Foundation; either version 2 or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Library General Public License for more details
 *
 *   You should have received a copy of the GNU Library General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.1
import QtQuick.Layouts 1.2
import org.kde.kirigami 2.0 as Kirigami
import org.kde.phone.calindori 0.1 as Calindori

Kirigami.ApplicationWindow {
    id: root

    /**
     * To be emitted when data displayed should be refreshed
     */
    signal refreshNeeded;

    /**
     * Creates the list of actions of 'Calendars' action container
     */
    function loadGlobalActions() {
        var cfgCalendars = calindoriConfig.calendars.split(calindoriConfig.calendars.includes(";") ? ";" : null);
        var currentChildren = calendarActions.children;
        var newChildren = [];

        //Preserve non-dynamic actions
        for(var i=0; i <currentChildren.length; ++i)
        {
            if(!(currentChildren[i].hasOwnProperty("isCalendar")))
            {
                newChildren.push(currentChildren[i]);
            }
        }

        //Add calendars from configuration
        for (var i=0; i < cfgCalendars.length; ++i)
        {
            newChildren.push(calendarAction.createObject(calendarActions, { text: cfgCalendars[i] }));
        }

        calendarActions.children = newChildren;
    }



    onRefreshNeeded: todosView.refreshNeeded()

    globalDrawer: Kirigami.GlobalDrawer {
        id: drawer

        title: "Calindori"
        actions: [
            Kirigami.Action {
                id: calendarActions

                text: "Calendars"
                iconName: "view-list-icons"

                Kirigami.Action {
                    text: "Add calendar..."
                    onTriggered: root.pageStack.push(calendarInputPage);
                }

                Kirigami.Action {
                    separator: true
                }
            }
        ]

        Component.onCompleted: root.loadGlobalActions()
    }

    contextDrawer: Kirigami.ContextDrawer {
        id: contextDrawer
    }

    pageStack.initialPage: [calendarDashboardComponent]
    pageStack.defaultColumnWidth: pageStack.width

    Calindori.Config {
        id: calindoriConfig

        onActiveCalendarChanged: root.loadGlobalActions()
        onCalendarsChanged: root.loadGlobalActions()
    }

    Calindori.LocalCalendar {
        id: localCalendar

        name: calindoriConfig.activeCalendar

        onNameChanged: root.refreshNeeded()
    }

    Component {
        id: calendarAction

        Kirigami.Action {

            property bool isCalendar: true

            checked: (text == calindoriConfig.activeCalendar)

            Kirigami.Action {
                text: "Activate"

                onTriggered: {
                    calindoriConfig.activeCalendar = parent.text;
                }
            }

            Kirigami.Action {
                text: "Delete"

                onTriggered: {
                    if (calindoriConfig.activeCalendar == parent.text) {
                        showPassiveNotification("Active calendar cannot be deleted");
                    }
                    else {
                        showPassiveNotification("Deleting calendar " + parent.text);
                        var toRemoveCalendarComponent =  Qt.createQmlObject("import org.kde.phone.calindori 0.1 as Calindori; Calindori.LocalCalendar { name: \"" + parent.text + "\"}",root);
                        toRemoveCalendarComponent.deleteCalendar();
                        calindoriConfig.removeCalendar(parent.text);
                    }
                }
            }

        }
    }

    Component {
        id: calendarDashboardComponent

        Kirigami.Page {

            title: calendarMonthView.currentMonthName + " " + calendarMonthView.currentYear

            actions {
                left: Kirigami.Action {
                    iconName: "go-previous"

                    onTriggered: calendarMonthView.previousMonth()
                }

                main: Kirigami.Action {
                    iconName: "view-calendar-day"

                    onTriggered: calendarMonthView.goToday()
                }

                right: Kirigami.Action {
                    iconName: "go-next"

                    onTriggered: calendarMonthView.nextMonth()
                }

                contextualActions: [
                    Kirigami.Action {
                        iconName: "view-calendar-tasks"
                        text: "Show tasks"

                        onTriggered: {
                            if(localCalendar.todosCount(calendarMonthView.selectedDate) > 0) {
                                root.pageStack.push(todosView, { todoDt: calendarMonthView.selectedDate });
                            }
                            else {
                                showPassiveNotification (i18n("There is no task for the day selected"));
                            }
                        }
                    },
                    Kirigami.Action {
                        iconName: "resource-calendar-insert"
                        text: "Add task"

                        onTriggered: root.pageStack.push(todoPage, { startdt: calendarMonthView.selectedDate} )
                    }
                ]
            }

            CalendarMonthView {
                id: calendarMonthView

                anchors.centerIn: parent

                todosCount: function (todosDate) {
                    return localCalendar.todosCount(todosDate);
                }

                onSelectedDateChanged: {
                    if (root.pageStack.depth > 1) {
                        root.pageStack.pop(null);
                    }
                }

                Connections {
                    target: root

                    onRefreshNeeded: calendarMonthView.refresh()
                }
            }
        }
    }

    TodosView {
        id: todosView

        calendar: localCalendar

        onEditTask: root.pageStack.push(todoPage, {  startdt: modelData.dtstart, uid: modelData.uid, todoData: modelData })
        onTaskDeleted: root.refreshNeeded()
    }

    Component {
        id: todoPage

        TodoPage {
            calendar: localCalendar

            onTaskeditcompleted: {
                //console.log("Closing todo page");
                root.refreshNeeded();
                root.pageStack.pop(todoPage);
            }
        }
    }

    Component {
        id: calendarInputPage

        CalendarInputPage {

            onCalendarAdded: {
                var calendarAddResult = "";
                calendarAddResult = calindoriConfig.addCalendar(calendarName);

                if(calendarAddResult != "")
                {
                    showPassiveNotification(calendarAddResult);
                    return;
                }

                if(activeCalendar)
                {
                    calindoriConfig.activeCalendar = calendarName;
                }
                root.refreshNeeded();
                root.pageStack.pop(calendarInputPage);
            }

            onCalendarAddCanceled: {
                root.pageStack.pop(calendarInputPage);
            }

        }
    }
}

