/*
* Copyright 2011 Google Inc. All Rights Reserved.
* 
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance  with the License.  
* You may obtain a copy of the License at
*
*    http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing,
* software distributed under the License is distributed on an
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
* KIND, either express or implied.  See the License for the
* specific language governing permissions and limitations
* under the License.
*/
package com.google.sampling.experiential.client;

import com.google.gwt.event.dom.client.ChangeEvent;
import com.google.gwt.event.dom.client.ChangeHandler;
import com.google.gwt.event.dom.client.ClickEvent;
import com.google.gwt.event.dom.client.ClickHandler;
import com.google.gwt.user.client.ui.CheckBox;
import com.google.gwt.user.client.ui.Composite;
import com.google.gwt.user.client.ui.HTML;
import com.google.gwt.user.client.ui.HasVerticalAlignment;
import com.google.gwt.user.client.ui.HorizontalPanel;
import com.google.gwt.user.client.ui.Label;
import com.google.gwt.user.client.ui.ListBox;
import com.google.gwt.user.client.ui.VerticalPanel;
import com.google.gwt.user.client.ui.Widget;
import com.google.sampling.experiential.shared.SignalScheduleDAO;

/**
 * Container for all scheduling configuration panels.
 * 
 * @author Bob Evans
 *
 */
public class SchedulePanel extends Composite {

  private static final boolean EVERYDAY = true;
  private VerticalPanel scheduleDetailsPanel;
  private SignalScheduleDAO schedule;

  public SchedulePanel(SignalScheduleDAO schedule) {
    this.schedule = schedule;

    VerticalPanel verticalPanel = new VerticalPanel();
    initWidget(verticalPanel);

    HorizontalPanel horizontalPanel = new HorizontalPanel();
    horizontalPanel.setSpacing(3);
    verticalPanel.add(horizontalPanel);

    Label lblSignalSchedule = new Label("Signal Schedule:");
    lblSignalSchedule.setStyleName("keyLabel");
    horizontalPanel.add(lblSignalSchedule);
    horizontalPanel.setCellVerticalAlignment(lblSignalSchedule, HasVerticalAlignment.ALIGN_MIDDLE);
    lblSignalSchedule.setWidth("114px");    
    
    final ListBox listBox = createScheduleTypeListBox();
    horizontalPanel.add(listBox);
    horizontalPanel.setCellVerticalAlignment(listBox, HasVerticalAlignment.ALIGN_MIDDLE);
    listBox.setVisibleItemCount(1);

    scheduleDetailsPanel = new VerticalPanel();
    verticalPanel.add(scheduleDetailsPanel);
    setPanelForScheduleType();
    addListSelectionListener(listBox);
    verticalPanel.add(createUserEditable(schedule));

  }

  private Widget createUserEditable(SignalScheduleDAO schedule2) {
    HorizontalPanel userEditablePanel = new HorizontalPanel();
    userEditablePanel.setSpacing(2);
    userEditablePanel.setVerticalAlignment(HasVerticalAlignment.ALIGN_MIDDLE);
    userEditablePanel.setWidth("");
    Label lblUserEditable = new Label("User Editable: ");
    lblUserEditable.setStyleName("gwt-Label-Header");
    userEditablePanel.add(lblUserEditable);

    final CheckBox userEditableCheckBox = new CheckBox("");
    userEditablePanel.add(userEditableCheckBox);
    userEditableCheckBox.setValue(schedule.getUserEditable() != null ? schedule.getUserEditable() : Boolean.TRUE);
    userEditableCheckBox.addClickHandler(new ClickHandler() {

      @Override
      public void onClick(ClickEvent event) {
        schedule.setUserEditable(userEditableCheckBox.getValue());
      }

    });
    return userEditablePanel;
  }

  private void addListSelectionListener(final ListBox listBox) {
    listBox.addChangeHandler(new ChangeHandler() {
      @Override
      public void onChange(ChangeEvent event) {
        int index = listBox.getSelectedIndex();
        schedule.setScheduleType(index);
        setPanelForScheduleType();
      }
    });
  }

  private void setPanelForScheduleType() {
    switch (schedule.getScheduleType()) {
      case 0:
        setDailyPanel(EVERYDAY);
        break;
      case 1:
        setWeekdayPanel(!EVERYDAY);
        break;
      case 2:
        setWeeklyPanel();
        break;
      case 3:
        setMonthlyPanel();
        break;
      case 4:
        setEsmPanel();
        break;
      case 5:
        scheduleDetailsPanel.clear();
        break;
      case 6:
        scheduleDetailsPanel.clear();
        scheduleDetailsPanel.add(new HTML("<b>Advanced is not implemented yet!</b>"));
        break;
      default:
        throw new IllegalArgumentException("No case to match default list selection!");
    }
  }

  private ListBox createScheduleTypeListBox() {
    final ListBox listBox = new ListBox();
    for (int i = 0; i < SignalScheduleDAO.SCHEDULE_TYPES_NAMES.length; i++) {
      listBox.addItem(SignalScheduleDAO.SCHEDULE_TYPES_NAMES[i]);
    }
    listBox.setSelectedIndex(schedule.getScheduleType() != null ? schedule.getScheduleType() : 0);
    return listBox;
  }

  protected void setEsmPanel() {
    setPanel(new EsmPanel(schedule));
  }

  private void setDailyPanel(boolean everyday) {
    setPanel(new DailyPanel(schedule));
  }

  private void setWeekdayPanel(boolean everyday) {
    setPanel(new DailyPanel(schedule));
  }

  private void setPanel(Widget panel) {
    scheduleDetailsPanel.clear();
    scheduleDetailsPanel.add(panel);
  }

  private void setWeeklyPanel() {
    setPanel(new WeeklyPanel(schedule));
  }

  private void setMonthlyPanel() {
    setPanel(new MonthlyPanel(schedule));
  }

}
