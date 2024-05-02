import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import TopicBulkActions from "discourse/components/modal/topic-bulk-actions";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicListHeader from "discourse/components/topic-list/topic-list-header";
import TopicListItem from "discourse/components/topic-list/topic-list-item";
import VisitedLine from "discourse/components/topic-list/visited-line";
import concatClass from "discourse/helpers/concat-class";
// import LoadMore from "discourse/mixins/load-more";
import { observes } from "discourse-common/utils/decorators";

export default class TopicList extends Component {
  // TODO: .extend(LoadMore)
  @service currentUser;
  @service modal;
  @service router;
  @service siteSettings;

  @tracked lastVisitedTopic;
  @tracked lastCheckedElementId;

  constructor() {
    super(...arguments);
    this.updateLastVisitedTopic();
  }

  get selected() {
    return this.args.bulkSelectHelper?.selected;
  }

  get bulkSelectEnabled() {
    return this.args.bulkSelectHelper?.bulkSelectEnabled;
  }

  get canDoBulkActions() {
    return this.currentUser?.canManageTopic && this.selected?.length;
  }

  get toggleInTitle() {
    return !this.bulkSelectEnabled && this.args.canBulkSelect;
  }

  get experimentalTopicBulkActionsEnabled() {
    return this.currentUser?.use_experimental_topic_bulk_actions;
  }

  get sortable() {
    return !!this.args.changeSort;
  }

  get showLikes() {
    return this.args.order === "likes";
  }

  get showOpLikes() {
    return this.args.order === "op_likes";
  }

  // TODO:
  @observes("topics.[]")
  topicsAdded() {
    // special case so we don't keep scanning huge lists
    if (!this.lastVisitedTopic) {
      this.updateLastVisitedTopic();
    }
  }

  // TODO:
  @observes("topics", "order", "ascending", "category", "top", "hot")
  lastVisitedTopicChanged() {
    this.updateLastVisitedTopic();
  }

  // TODO
  scrolled() {
    // this._super(...arguments);
    let onScroll = this.onScroll;
    if (!onScroll) {
      return;
    }

    onScroll.call(this);
  }

  updateLastVisitedTopic() {
    const { topics, order, ascending, top, hot } = this.args;

    this.lastVisitedTopic = null;

    if (
      !this.args.highlightLastVisited ||
      top ||
      hot ||
      ascending ||
      !topics ||
      topics.length === 1 ||
      (order && order !== "activity") ||
      !this.currentUser?.previous_visit_at
    ) {
      return;
    }

    // this is more efficient cause we keep appending to list
    // work backwards
    const start = topics.findIndex((topic) => !topic.pinned);
    let lastVisitedTopic, topic;

    for (let i = topics.length - 1; i >= start; i--) {
      if (topics[i].bumpedAt > this.currentUser.previousVisitAt) {
        lastVisitedTopic = topics[i];
        break;
      }
      topic = topics[i];
    }

    if (!lastVisitedTopic || !topic) {
      return;
    }

    // end of list that was scanned
    if (topic.bumpedAt > this.currentUser.previousVisitAt) {
      return;
    }

    this.lastVisitedTopic = lastVisitedTopic;
  }

  click(e) {
    const onClick = (sel, callback) => {
      let target = e.target.closest(sel);

      if (target) {
        callback(target);
      }
    };

    onClick("button.bulk-select", () => {
      this.args.bulkSelectHelper.toggleBulkSelect();
      this.rerender();
    });

    onClick("button.bulk-select-all", () => {
      this.args.bulkSelectHelper.autoAddTopicsToBulkSelect = true;
      document
        .querySelectorAll("input.bulk-select:not(:checked)")
        .forEach((el) => el.click());
    });

    onClick("button.bulk-clear-all", () => {
      this.args.bulkSelectHelper.autoAddTopicsToBulkSelect = false;
      document
        .querySelectorAll("input.bulk-select:checked")
        .forEach((el) => el.click());
    });

    onClick("th.sortable", (element) => {
      this.changeSort(element.dataset.sortOrder);
      this.rerender();
    });

    onClick("button.bulk-select-actions", () => {
      this.modal.show(TopicBulkActions, {
        model: {
          topics: this.selected,
          category: this.category,
          refreshClosure: () => this.router.refresh(),
        },
      });
    });

    onClick("button.topics-replies-toggle", (element) => {
      if (element.classList.contains("--all")) {
        this.args.changeNewListSubset(null);
      } else if (element.classList.contains("--topics")) {
        this.args.changeNewListSubset("topics");
      } else if (element.classList.contains("--replies")) {
        this.args.changeNewListSubset("replies");
      }
      this.rerender();
    });
  }

  keyDown(e) {
    if (e.key === "Enter" || e.key === " ") {
      let onKeyDown = (sel, callback) => {
        let target = e.target.closest(sel);

        if (target) {
          callback.call(this, target);
        }
      };

      onKeyDown("th.sortable", (element) => {
        this.changeSort(element.dataset.sortOrder);
        this.rerender();
      });
    }
  }

  <template>
    <table
      class={{concatClass
        "topic-list"
        (if this.bulkSelectEnabled "sticky-header")
      }}
    >
      <thead class="topic-list-header">
        <TopicListHeader
          @canBulkSelect={{@canBulkSelect}}
          @toggleInTitle={{this.toggleInTitle}}
          @hideCategory={{@hideCategory}}
          @showPosters={{@showPosters}}
          @showLikes={{this.showLikes}}
          @showOpLikes={{this.showOpLikes}}
          @order={{@order}}
          @ascending={{@ascending}}
          @sortable={{this.sortable}}
          @listTitle={{or @listTitle "topic.title"}}
          @bulkSelectEnabled={{this.bulkSelectEnabled}}
          @bulkSelectHelper={{@bulkSelectHelper}}
          @experimentalTopicBulkActionsEnabled={{this.experimentalTopicBulkActionsEnabled}}
          @canDoBulkActions={{this.canDoBulkActions}}
          @showTopicsAndRepliesToggle={{@showTopicsAndRepliesToggle}}
          @newListSubset={{@newListSubset}}
          @newRepliesCount={{@newRepliesCount}}
          @newTopicsCount={{@newTopicsCount}}
        />
      </thead>

      <PluginOutlet
        @name="before-topic-list-body"
        @outletArgs={{hash
          topics=@topics
          selected=this.selected
          bulkSelectEnabled=this.bulkSelectEnabled
          lastVisitedTopic=this.lastVisitedTopic
          discoveryList=@discoveryList
          hideCategory=@hideCategory
        }}
      />

      <tbody class="topic-list-body">
        {{#each @topics as |topic index|}}
          <TopicListItem
            @topic={{topic}}
            @bulkSelectEnabled={{this.bulkSelectEnabled}}
            @showTopicPostBadges={{@showTopicPostBadges}}
            @hideCategory={{@hideCategory}}
            @showPosters={{@showPosters}}
            @showLikes={{this.showLikes}}
            @showOpLikes={{this.showOpLikes}}
            @expandGloballyPinned={{@expandGloballyPinned}}
            @expandAllPinned={{@expandAllPinned}}
            @lastVisitedTopic={{this.lastVisitedTopic}}
            @selected={{this.selected}}
            @lastCheckedElementId={{this.lastCheckedElementId}}
            @updateLastCheckedElementId={{fn (mut this.lastCheckedElementId)}}
            @tagsForUser={{@tagsForUser}}
            @focusLastVisitedTopic={{@focusLastVisitedTopic}}
            @index={{index}}
          />

          <VisitedLine
            @lastVisitedTopic={{this.lastVisitedTopic}}
            @topic={{topic}}
          />

          <PluginOutlet
            @name="after-topic-list-item"
            @outletArgs={{hash topic=topic index=index}}
            @connectorTagName="tr"
          />
        {{/each}}
      </tbody>

      <PluginOutlet
        @name="after-topic-list-body"
        @outletArgs={{hash
          topics=@topics
          selected=this.selected
          bulkSelectEnabled=this.bulkSelectEnabled
          lastVisitedTopic=this.lastVisitedTopic
          discoveryList=@discoveryList
          hideCategory=@hideCategory
        }}
      />
    </table>
  </template>
}
