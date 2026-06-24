defmodule Medoru.Repo.Migrations.CreateClassroomChatsForExisting do
  use Ecto.Migration

  import Ecto.Query

  alias Medoru.Repo
  alias Medoru.Chat.{Conversation, ConversationParticipant}
  alias Medoru.Classrooms.ClassroomMembership

  def up do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Find all classrooms without a linked conversation.
    # Select only columns that exist at this point in time so adding later
    # columns (e.g. classrooms.theme) does not break this migration.
    classrooms_without_chat =
      Repo.all(
        from(c in "classrooms",
          left_join: conv in "conversations",
          on: conv.classroom_id == c.id,
          where: is_nil(conv.id),
          select: %{
            id: c.id,
            name: c.name,
            teacher_id: c.teacher_id,
            inserted_at: c.inserted_at
          }
        )
      )

    for classroom <- classrooms_without_chat do
      # Create the conversation using insert_all with the schema module so UUIDs
      # are encoded properly, but pass only the columns that exist now.
      conversation_id = Ecto.UUID.generate()

      Repo.insert_all(Conversation, [
        %{
          id: conversation_id,
          title: classroom.name,
          is_group: true,
          classroom_id: classroom.id,
          started_at: classroom.inserted_at || now,
          inserted_at: now,
          updated_at: now
        }
      ])

      # Add teacher as participant
      Repo.insert_all(ConversationParticipant, [
        %{
          id: Ecto.UUID.generate(),
          conversation_id: conversation_id,
          user_id: classroom.teacher_id,
          joined_at: classroom.inserted_at || now,
          has_left: false,
          is_typing: false,
          inserted_at: now,
          updated_at: now
        }
      ])

      # Add all approved members as participants
      approved_members =
        Repo.all(
          from(m in ClassroomMembership,
            where: m.classroom_id == ^classroom.id and m.status == :approved,
            select: %{
              user_id: m.user_id,
              joined_at: m.joined_at,
              inserted_at: m.inserted_at
            }
          )
        )

      for member <- approved_members do
        Repo.insert_all(ConversationParticipant, [
          %{
            id: Ecto.UUID.generate(),
            conversation_id: conversation_id,
            user_id: member.user_id,
            joined_at: member.joined_at || member.inserted_at || now,
            has_left: false,
            is_typing: false,
            inserted_at: now,
            updated_at: now
          }
        ])
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
