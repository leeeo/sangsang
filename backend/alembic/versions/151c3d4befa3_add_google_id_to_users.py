"""add_google_id_to_users

Revision ID: 151c3d4befa3
Revises: 49e7713da53a
Create Date: 2026-05-13 09:41:05.815808

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '151c3d4befa3'
down_revision: Union[str, None] = '49e7713da53a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # SQLite는 ALTER COLUMN을 지원하지 않으므로 batch_alter_table 사용
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('google_id', sa.String(length=255), nullable=True))
        batch_op.alter_column('hashed_password',
                              existing_type=sa.VARCHAR(length=255),
                              nullable=True)
        batch_op.create_index('ix_users_google_id', ['google_id'], unique=True)


def downgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_index('ix_users_google_id')
        batch_op.alter_column('hashed_password',
                              existing_type=sa.VARCHAR(length=255),
                              nullable=False)
        batch_op.drop_column('google_id')
