defmodule Medoru.Repo.Migrations.CreateClassroomChatsForExisting do
  use Ecto.Migration

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Chat.{Conversation, ConversationParticipant}
  alias Medoru.Classrooms.{Classroom, ClassroomMembership}

  def up do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Find all classrooms without a linked conversation
    classrooms_without_chat =
      Repo.all(
        from c in Classroom,
          left_join: conv in Conversation,
            on: conv.classroom_id == c.id,
          where: is_nil(conv.id),
          select: c
      )

    for classroom <- classrooms_without_chat do
      # Create the conversation
      {:ok, conversation} =
        %Conversation{}
        |> Ecto.Changeset.change(%{
          title: classroom.name,
          is_group: true,
          classroom_id: classroom.id,
          started_at: classroom.inserted_at || now
        })
        |> Repo.insert()

      # Add teacher as participant
      # Use insert_all with schema module (not raw table name) so UUIDs are encoded properly,
      # but we only pass the columns that exist at this point in time.
      Repo.insert_all(ConversationParticipant, [%{
        id: Ecto.UUID.generate(),
        conversation_id: conversation.id,
        user_id: classroom.teacher_id,
        joined_at: classroom.inserted_at || now,
        has_left: false,
        is_typing: false,
        inserted_at: now,
        updated_at: now
      }])

      # Add all approved members as participants
      approved_members =
        Repo.all(
          from m in ClassroomMembership,
            where: m.classroom_id == ^classroom.id and m.status == :approved,
            select: m
        )

      for member <- approved_members do
        Repo.insert_all(ConversationParticipant, [%{
          id: Ecto.UUID.generate(),
          conversation_id: conversation.id,
          user_id: member.user_id,
          joined_at: member.joined_at || member.inserted_at || now,
          has_left: false,
          is_typing: false,
          inserted_at: now,
          updated_at: now
        }])
      end
    end
  end

  def down do
    # This migration is not reversible in a meaningful way.
    # The conversations created here would have messages and participants
    # that we don't want to accidentally delete.
    :ok
  end
end
